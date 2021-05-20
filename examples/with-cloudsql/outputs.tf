output "service_account_email" {
  description = "The service account of the cluster"
  value = module.mig.service_account_email
}

output "ilb_address" {
  description = "The address of the Internal LB"
  value = module.mig.ilb_address
}

output "ilb_ports" {
  description = "The ports that the Internal LB is serving"
  value = module.mig.ilb_ports
}

output "allowed_source_ranges" {
  description = "The allowed CIDRs to connect to the cluster"
  value = module.mig.allowed_source_ranges
}