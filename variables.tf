variable "access_config" {
  description = "Access configurations, i.e. IPs via which the VM instance can be accessed via the Internet."
  type = list(object({
    nat_ip       = string
    network_tier = string
  }))
  default = []
}

variable "allowed_admins" {
  description = "Allowed to remote access to the instances, i.e some Users or serviceAccounts"
  type        = list(string)
}

variable "allowed_source_ranges" {
  description = "Trusted ip ranges to access the instances"
  type        = list(string)
}

variable "cluster_description" {
  description = "The description of the cluster"
  type        = string
}

variable "cluster_labels" {
  description = "The labels of the cluster"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "cluster_ports" {
  description = "The port of the load balancer to listen"
  type        = list(string)
}

variable "cluster_size" {
  description = "The size of the cluster"
  type        = string
}

variable "cluster_tags" {
  description = "The tag of the cluster. All members of this cluster will inherits the same tags"
  type        = list(string)
}

variable "distribution_policy_zones" {
  description = "The distribution policy, i.e. which zone(s) should instances be create in. Default is all zones in given region."
  type        = list(string)
  default     = []
}

variable "enable_confidential_vm" {
  default     = false
  description = "Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images"
}

variable "enable_shielded_vm" {
  default     = false
  description = "Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images"
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

variable "instance_disk_size" {
  description = "The size of the boot disk"
  type        = string
}

variable "instance_disk_type" {
  description = "The type of the boot disk"
  type        = string
  default     = "pd-ssd"
}

variable "machine_type" {
  description = "The type of the instances"
  type        = string
  default     = "n1-standard-1"
}

variable "mig_timeouts" {
  description = "Times for creation, deleting and updating the MIG resources. Can be helpful when using wait_for_instances to allow a longer VM startup time. "
  type = object({
    create = string
    update = string
    delete = string
  })
  default = {
    create = "5m"
    update = "5m"
    delete = "15m"
  }
}

variable "min_cpu_platform" {
  description = "Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform"
  type        = string
  default     = null
}

variable "named_ports" {
  description = "Named name and named port. https://cloud.google.com/load-balancing/docs/backend-service#named_ports"
  type = list(object({
    name = string
    port = number
  }))
  default = []
}

variable "network" {
  description = "The network of the cluster"
  type        = string
  default     = "default"
}

variable "network_ip" {
  description = "Private IP address to assign to the instance if desired."
  default     = ""
}

variable "project_id" {
  description = "The id of the GCP project that this cluster belongs to. If not define then it will use the provider default"
  type        = string
  default     = null
}

variable "random_role_id" {
  type = bool

  description = "Enables role random id generation."
  default     = true
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = null
}

variable "service_account_email" {
  type = string

  description = "If set, the service account and its permissions will not be created. The service account being passed in should have at least the roles listed in the `service_account_roles` variable so that logging and OS Login work as expected."
  default     = ""
}

variable "service_account_roles" {
  type = list(string)

  description = "List of IAM roles to assign to the service account."
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/compute.osLogin",
  ]
}

variable "service_account_roles_supplemental" {
  type = list(string)

  description = "An additional list of roles to assign to the bastion if desired"
  default     = []
}

variable "shielded_instance_config" {
  description = "Not used unless enable_shielded_vm is true. Shielded VM configuration for the instance."
  type = object({
    enable_secure_boot          = bool
    enable_vtpm                 = bool
    enable_integrity_monitoring = bool
  })

  default = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

variable "source_image" {
  description = "The source image to use"
  type        = string
  default     = ""
}

variable "source_image_family" {
  description = "The source image family to use"
  type        = string
  default     = "debian-9"
}

variable "source_image_project" {
  description = "The GCP project of the source image"
  type        = string
  default     = "debian-cloud"
}

variable "source_tags" {
  description = "The tags of the incoming traffic"
  type        = list(string)
  default     = []
}

variable "subnetwork" {
  description = "The VPC that this cluster belongs to"
  type        = string
  default     = "default"
}

variable "target_pools" {
  description = "The target pools"
  type        = list(string)
  default     = []
}

variable "update_policy" {
  description = "The rolling update policy. https://www.terraform.io/docs/providers/google/r/compute_region_instance_group_manager.html#rolling_update_policy"
  type = list(object({
    max_surge_fixed              = number
    instance_redistribution_type = string
    max_surge_percent            = number
    max_unavailable_fixed        = number
    max_unavailable_percent      = number
    min_ready_sec                = number
    minimal_action               = string
    type                         = string
  }))
  default = []
}
