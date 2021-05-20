# High-Availability PgBouncer MIG Terraform Module

Terraform module to create following resources:  
* MIG with regional distribution & healthcheck  
* Internal load balancer to distribute traffic among the instances  
* Vault secret injection using GCP Authentication (requires an existing Vault server with GCP Auth enabled)  

## Compatibility
This module is meant for use with Terraform 0.13. If you haven't
[upgraded](https://www.terraform.io/upgrade-guides/0-13.html) and need a Terraform
0.12.x-compatible version of this module, the last released version
intended for Terraform 0.12.x is [v2.3.0](https://registry.terraform.io/modules/terraform-google-modules/-lb-internal/google/v2.3.0).

## Build the image before use the module  

In order to let the module works, you must build the image to use with the module. Please refer to the `scripts/buildpkr.hcl` to check the configuration and build the image with Packer ( requires Packer >= 1.7.2 to works )  

## Usage

```hcl
module "mig" {
  source                = "github.com/mindvalley/tf-module-pgbouncer-mig"
  cluster_name          = "pgbouncer"
  instance_disk_size    = "100"
  allowed_admins        = ["someuser@example.com"]
  cluster_description   = "This is a test pgbouncer cluster"
  allowed_source_ranges = ["10.148.0.0/20"]
  cluster_ports         = ["6432"]
  cluster_size          = "3"
  cluster_tags          = ["test", "pgbouncer"]
  cluster_labels        = {
    "roles" = "pgbouncer"
    "scopes" = "cloudsql"
  }
  machine_type          = "g1-small"
  enabled_databases     = [
    {
    name                       = "mydb"
    host                       = "10.10.0.3"
    port                       = 5432
    pool_size                  = 20
    username                   = "user1"
    password_vault_secret_path = "secret/test_db" 
    }
  ]
  pgbouncer_config      = {
    listen_port                = 6432
    listen_addr                = "0.0.0.0"
    max_client_conn            = 4000
  }
  vault_config          = {
    vault_server_address = "https://127.0.0.1:8200"
    vault_cluster_role   = "pgbouncer-gce-role"
    tls_skip_verify      = "true"
  }
  network               = "default"
  named_ports           = [
    {
      name = "pgbouncer"
      port = 6432
    },
    {
      name = "healthz"
      port = 8000
    }
  ]
  project_id            = var.project_id
  random_role_id        = true
  region                = var.region
  source_image_family   = "mv-pgbouncer"
  source_image_project  = var.project_id
  source_tags           = ["allow-group"]
  subnetwork            = "default"
  health_check          = {
    initial_delay_sec   = 30
    check_interval_sec  = 30
    enable_log          = false
    healthy_threshold   = 1
    host                = ""
    port                = 8000
    port_name           = "healthz"
    proxy_header        = "NONE"
    request             = ""
    request_path        = "/health"
    response            = ""
    timeout_sec         = 10
    type                = "http"
    unhealthy_threshold = 5
  }
  update_policy         = [
    {
      type                         = "PROACTIVE"
      instance_redistribution_type = "PROACTIVE"
      minimal_action               = "REPLACE"
      max_surge_fixed              = 3
      max_unavailable_fixed        = 0
      min_ready_sec                = 60
    }
  ]
}
```

## Addons  

Each instance in the MIG has following addons pre-installed and pre-configured to work with the pgbouncer:  
* pgbouncer-exporter is running at http://${address}:9127/metrics  
* pgbouncer_healthcheck is running at http://${address}:8000/health  
* node_exporter is running at http://${address}:9100/metrics  

The reason to have these addons is to let Prometheus scrapes the metrics for visualizations / alerts.  

