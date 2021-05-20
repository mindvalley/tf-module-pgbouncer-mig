# Example with CloudSQL and PgBouncer  

This example shows how to create a CloudSQL(Postgres) instance and provision a PgBouncer MIG.  

## Vault intergration  

This example does not create Vault for you. You need to either use your existing Vault or create a new one.  
Before testing, make sure that you already enabled the Vault GCP Auth, as per this guide https://www.vaultproject.io/docs/auth/gcp.  

Since this module was designed to work with the `gce` type role, we don't guarantee that it will work with the `iam` type role. You must create a role before hand, for example  

```
vault write auth/gcp/role/my-gce-role \
    type="gce" \
    policies="dev,prod" \
    bound_projects="my-project1,my-project2" \
    bound_zones="us-east1-b" \
    bound_labels="foo:bar,zip:zap" \
    bound_service_accounts="my-service@my-project.iam.gserviceaccount.com"
```

The variable `cluster_labels` must contains the set of labels defined in `bound_labels` so that vaut agent can authenticates against Vault server.  

## Run Terraform  

```
terraform init
terraform plan
terraform apply
```

## Test  

Create a VM within the `allowed_source_ranges` and then connecting to the address and port of the created Internal LB.  

## Cleanup  

```
terraform destroy
```