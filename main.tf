resource "random_id" "random_role_id_suffix" {
  byte_length = 2
}

locals {
  service_account_email = var.service_account_email == "" ? google_service_account.cluster_sa[0].email : var.service_account_email
  service_account_roles = var.service_account_email == "" ? toset(compact(concat(
    var.service_account_roles,
    var.service_account_roles_supplemental,
  ))) : []
  base_role_id = "osLoginProjectGet"
  temp_role_id = var.random_role_id ? format(
    "%s_%s",
    local.base_role_id,
    random_id.random_role_id_suffix.hex,
  ) : local.base_role_id
  distribution_policy_zones_base = {
    default = data.google_compute_zones.available.names
    user    = var.distribution_policy_zones
  }
  distribution_policy_zones = local.distribution_policy_zones_base[length(var.distribution_policy_zones) == 0 ? "default" : "user"]

  # NOTE: Even if all the shielded_instance_config or confidential_instance_config
  # values are false, if the config block exists and an unsupported image is chosen,
  # the apply will fail so we use a single-value array with the default value to
  # initialize the block only if it is enabled.
  shielded_vm_configs          = var.enable_shielded_vm ? [true] : []
  confidential_instance_config = var.enable_confidential_vm ? [true] : []

}

resource "google_service_account" "cluster_sa" {
  count        = var.service_account_email == "" ? 1 : 0
  account_id   = "${var.cluster_name}-cluster-sa"
  display_name = "Terraform-managed SA for PgBouncer Cluster"
  project      = var.project_id
}

resource "google_service_account_iam_binding" "cluster_sa_user" {
  count              = var.service_account_email == "" ? 1 : 0
  service_account_id = google_service_account.cluster_sa[0].id
  role               = "roles/iam.serviceAccountUser"
  members            = var.allowed_admins
}

resource "google_project_iam_member" "cluster_sa_bindings" {
  for_each = local.service_account_roles
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${local.service_account_email}"
}

# If you are practicing least privilege, to enable instance level OS Login, you
# still need the compute.projects.get permission on the project level. The other
# predefined roles grant additional permissions that aren't needed
resource "google_project_iam_custom_role" "compute_os_login_viewer" {
  count       = var.service_account_email == "" ? 1 : 0
  project     = var.project_id
  role_id     = local.temp_role_id
  title       = "OS Login Project Get Role"
  description = "From Terraform: iap-bastion module custom role for more fine grained scoping of permissions"
  permissions = ["compute.projects.get"]
}

resource "google_project_iam_member" "oslogin_bindings" {
  count   = var.service_account_email == "" ? 1 : 0
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.compute_os_login_viewer[0].role_id}"
  member  = "serviceAccount:${local.service_account_email}"
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_health_check" "autohealing" {
  name                = "${var.cluster_name}-autohealing-health-check"
  project             = var.project_id
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/health"
    port         = "8000"
  }
}
resource "google_compute_region_instance_group_manager" "pgbouncer" {
  provider = google-beta
  name     = "${var.cluster_name}-ig"

  project                   = var.project_id
  base_instance_name        = "pgbouncer"
  region                    = var.region
  distribution_policy_zones = local.distribution_policy_zones

  version {
    name              = "pgbouncer-mig-version-0"
    instance_template = google_compute_instance_template.pgbouncer.id
  }

  dynamic "update_policy" {
    for_each = var.update_policy
    content {
      instance_redistribution_type = lookup(update_policy.value, "instance_redistribution_type", null)
      max_surge_fixed              = lookup(update_policy.value, "max_surge_fixed", null)
      max_surge_percent            = lookup(update_policy.value, "max_surge_percent", null)
      max_unavailable_fixed        = lookup(update_policy.value, "max_unavailable_fixed", null)
      max_unavailable_percent      = lookup(update_policy.value, "max_unavailable_percent", null)
      min_ready_sec                = lookup(update_policy.value, "min_ready_sec", null)
      minimal_action               = update_policy.value.minimal_action
      type                         = update_policy.value.type
    }
  }

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = lookup(named_port.value, "name", null)
      port = lookup(named_port.value, "port", null)
    }
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 30
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [distribution_policy_zones]
  }

  timeouts {
    create = var.mig_timeouts.create
    update = var.mig_timeouts.update
    delete = var.mig_timeouts.delete
  }

  target_pools = var.target_pools
  target_size  = var.cluster_size

}

data "google_compute_image" "image" {
  project = var.source_image != "" ? var.source_image_project : "centos-cloud"
  name    = var.source_image != "" ? var.source_image : "centos-7-v20201112"
}

data "google_compute_image" "image_family" {
  project = var.source_image_family != "" ? var.source_image_project : "centos-cloud"
  family  = var.source_image_family != "" ? var.source_image_family : "centos-7"
}

data "template_file" "init" {
  template = file("${path.module}/scripts/startup.sh.tpl")
  vars = {
    consul_address = "1.2.3.4"
  }
}

resource "google_compute_instance_template" "pgbouncer" {
  name_prefix = var.cluster_name
  description = var.cluster_description
  project     = var.project_id
  region      = var.region

  instance_description    = var.cluster_description
  machine_type            = var.machine_type
  metadata_startup_script = data.template_file.init.rendered
  min_cpu_platform        = var.min_cpu_platform

  tags           = var.cluster_tags
  labels         = var.cluster_labels
  can_ip_forward = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = var.source_image != "" ? data.google_compute_image.image.self_link : data.google_compute_image.image_family.self_link
    boot         = true
    auto_delete  = true
    disk_size_gb = var.instance_disk_size
    disk_type    = var.instance_disk_type
  }

  service_account {
    email  = local.service_account_email
    scopes = ["cloud-platform"]
  }

  network_interface {
    network            = var.network
    subnetwork         = var.subnetwork
    subnetwork_project = var.project_id
    network_ip         = length(var.network_ip) > 0 ? var.network_ip : null
    dynamic "access_config" {
      for_each = var.access_config
      content {
        nat_ip       = access_config.value.nat_ip
        network_tier = access_config.value.network_tier
      }
    }
  }

  lifecycle {
    create_before_destroy = "true"
  }

  dynamic "shielded_instance_config" {
    for_each = local.shielded_vm_configs
    content {
      enable_secure_boot          = lookup(var.shielded_instance_config, "enable_secure_boot", shielded_instance_config.value)
      enable_vtpm                 = lookup(var.shielded_instance_config, "enable_vtpm", shielded_instance_config.value)
      enable_integrity_monitoring = lookup(var.shielded_instance_config, "enable_integrity_monitoring", shielded_instance_config.value)
    }
  }

  confidential_instance_config {
    enable_confidential_compute = var.enable_confidential_vm
  }
}

module "gce-ilb" {
  source           = "GoogleCloudPlatform/lb-internal/google"
  version          = "~> 2.0"
  project          = var.project_id
  region           = var.region
  global_access    = true
  name             = "${var.cluster_name}-ilb"
  ports            = var.cluster_ports
  health_check     = var.health_check
  source_tags      = var.source_tags
  source_ip_ranges = var.allowed_source_ranges
  target_tags      = var.cluster_tags
  backends = [
    { group = google_compute_region_instance_group_manager.pgbouncer.instance_group, description = "" }
  ]
}
