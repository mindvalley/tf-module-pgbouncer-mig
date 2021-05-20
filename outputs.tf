output "service_account_email" {
  description = "The service account of the cluster"
  value = local.service_account_email
}

output "ilb_address" {
  description = "The address of the Internal LB"
  value = module.gce-ilb.ip_address
}

output "ilb_ports" {
  description = "The ports that the Internal LB is serving"
  value = var.cluster_ports
}

output "allowed_source_ranges" {
  description = "The allowed CIDRs to connect to the cluster"
  value = var.allowed_source_ranges
}