# PGBOUNCER HIGH-AVALIABLITY MIG DESIGN  

## Placement and Networking

In each project that contains CloudSQL instance(s), we will place a single MIG for the PgBouncer. Although this is not a hard requirement, having multiple MIGs could be problematic in operations and maintenance. This PgBouncer MIG will be responsible for all the CloudSQL Instances in the project. 

The MIG will run on a specific network, it could be an existing VPC, or we can create a new VPC, depends on the environment. But in a project, 

## Custom Image Buid  

What need to be add into the custom image, built via Packer:  
* OS version: Ubuntu 20.04 LTS
* PgBouncer version: 1.15.0
* Node-Exporter version: 1.1.2
* PgBouncer-Exporter version: 0.4.0
* Hashicorp Vault version: 1.7.1
* PgBouncer-Healthcheck version: `master` from https://github.com/deliveroo/pgbouncer-healthcheck. We may need to pre-compiled the binary during build time  

Pre-defined OS Configuration with the image:  
* Increase the open file limits to 4000
* Disable ipv4 forwarding

## Terraform Resources  

A [google_compute_instance_group_manager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group_manager) to control how many instances to be created in a group  
A [google_compute_instance_template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) to control the instance template of the instance group. This is where we configure the actual instance configuration, like disk size, network interface , service account etc....  
Five [template_files](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) to render needed configurations and scripts:  
  * vault agent config  
  * vault agent template  
  * node-exporter config  
  * pgbouncer-exporter config
  * pgbouncer template for vault agent  

An [internal load balancer](https://github.com/terraform-google-modules/terraform-google-lb-internal) to load balancing the traffic with health check enabled. This load balancer will have Global Access enabled, to allows clients from other regions connecting to it.  

A [google_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account) to allow the instances to access certain GCP's services, such as GCE Metadata API and Vault authentication.

A [google_compute_firewall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) to only allow trusted networks to access the load balancer.  