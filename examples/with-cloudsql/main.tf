data "google_compute_network" "network" {
  project = var.project_id
  name    = "default"
}

module "private-service-access" {
  source     = "GoogleCloudPlatform/sql-db/google//modules//private_service_access"
  project_id = var.project_id
  vpc_network     = "default"
}

module "postgresql-db" {
  source               = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  name                 = "test"
  random_instance_name = true
  database_version     = "POSTGRES_11"
  project_id           = var.project_id
  zone                 = "asia-southeast1-a"
  region               = "asia-southeast1"
  tier                 = "db-f1-micro"
  create_timeout       = "30m"
  delete_timeout       = "30m"
  update_timeout       = "30m"
  enable_default_db    = false
  enable_default_user  = false

  deletion_protection = false

  ip_configuration = {
    ipv4_enabled        = false
    private_network     = data.google_compute_network.network.id
    require_ssl         = false
    authorized_networks = []
  }

  depends_on = [module.private-service-access]

}

module "mig" {
  source                = "../../"
  cluster_name          = var.cluster_name
  instance_disk_size    = var.instance_disk_size
  allowed_admins        = var.allowed_admins
  cluster_description   = var.cluster_description
  allowed_source_ranges = ["10.148.0.0/20"]
  cluster_ports         = var.cluster_ports
  cluster_size          = var.cluster_size
  cluster_tags          = var.cluster_tags
  cluster_labels        = var.cluster_labels
  machine_type          = var.machine_type
  enabled_databases     = var.enabled_databases
  pgbouncer_config      = var.pgbouncer_config
  vault_config          = var.vault_config
  network               = var.network
  named_ports           = var.named_ports
  project_id            = var.project_id
  random_role_id        = true
  region                = var.region
  source_image_family   = "mv-pgbouncer"
  source_image_project  = var.project_id
  source_tags           = ["allow-group"]
  subnetwork            = "default"
  health_check          = var.health_check
  update_policy         = var.update_policy
}
