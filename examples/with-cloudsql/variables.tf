variable "allowed_admins" {
  type        = list(string)
  description = ""
}

variable "cluster_description" {
  type        = string
  description = ""
}

variable "cluster_labels" {
  type        = map(string)
  description = ""
}

variable "cluster_name" {
  type        = string
  description = ""
}

variable "cluster_ports" {
  type        = list(string)
  description = ""
  default = ["6432"]
}

variable "cluster_size" {
  type        = string
  description = ""
  default = "1"
}

variable "cluster_tags" {
  type        = list(string)
  description = ""
}

variable "enabled_databases" {
  type = list(object({
    name                       = string
    username                   = string
    host                       = string
    port                       = number
    pool_size                  = number
    password_vault_secret_path = string
  }))
  description = ""
}

variable "pgbouncer_config" {
  description = "Parameters of the pgbpouncer"
  type = object({
    listen_port                = number
    listen_addr                = string
    max_client_conn            = number
  })
  default = {
    listen_port                = 6432
    listen_addr                = "0.0.0.0"
    max_client_conn            = 4000
  }
}

variable "instance_disk_size" {
  type        = string
  description = ""
  default = "20"
}

variable "machine_type" {
  type = string
}

variable "network" {
  type        = string
  description = ""
}

variable "project_id" {
  type        = string
  description = ""
}

variable "region" {
  type        = string
  description = ""
}

variable "health_check" {
  description = "Health check to determine whether instances are responsive and able to do work"
  type = object({
    type                = string
    check_interval_sec  = number
    healthy_threshold   = number
    timeout_sec         = number
    unhealthy_threshold = number
    response            = string
    proxy_header        = string
    port                = number
    port_name           = string
    request             = string
    request_path        = string
    host                = string
    enable_log          = bool
  })
  default = {
    type                = ""
    check_interval_sec  = 30
    healthy_threshold   = 1
    timeout_sec         = 10
    unhealthy_threshold = 5
    response            = ""
    proxy_header        = "NONE"
    port                = 8000
    port_name           = "healthz"
    request             = ""
    request_path        = "/health"
    host                = ""
    enable_log          = false
  }
}

variable "vault_config" {
  description = "Parameters to add into vault agent configuration"
  type = object({
    vault_server_address = string
    vault_cluster_role   = string
    tls_skip_verify      = string
  })
  default = {
    vault_server_address = "http://127.0.0.1:8200"
    vault_cluster_role   = "default_gce_vault_role"
    tls_skip_verify      = "false"
  }
}

variable "update_policy" {
  description = "The rolling update policy. https://www.terraform.io/docs/providers/google/r/compute_region_instance_group_manager.html#rolling_update_policy"
  type = list(object({
    max_surge_fixed              = optional(number)
    instance_redistribution_type = optional(string)
    max_surge_percent            = optional(number)
    max_unavailable_fixed        = optional(number)
    max_unavailable_percent      = optional(number)
    min_ready_sec                = optional(number)
    minimal_action               = string
    type                         = string
  }))
  default = []
}

variable "named_ports" {
  description = "Named name and named port. https://cloud.google.com/load-balancing/docs/backend-service#named_ports"
  type = list(object({
    name = string
    port = number
  }))
  default = []
}