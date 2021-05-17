# build.pkr.hcl
variables {
  project_id = "mv-dev-alexco"
  source_image_name = "ubuntu-2004-focal-v20201014"
  zone = "asia-southeast1-a"
  machine_type = "n1-standard-1"
  disk_size = 20
  subnetwork = "default"
  ssh_username = "ubuntu"
  go_path = env("GOPATH")
}

source "googlecompute" "pgbouncer-build" {
  source_image = var.source_image_name
  project_id = var.project_id
  zone = var.zone
  image_name = "mv-pgbouncer-${uuidv4()}"
  image_family = "mv-pgbouncer"
  ssh_username = var.ssh_username
}

build {
    # use the `name` field to name a build in the logs.
    # For example this present config will display
    # "buildname.amazon-ebs.example-1" and "buildname.amazon-ebs.example-2"
    name = "pgbouncer-ubuntu20-image"

    sources = ["sources.googlecompute.pgbouncer-build"]

    provisioner "shell" {
        inline = [
          "echo ====== Install packages =======",
          "sudo apt update -y",
          "sudo apt install -y pgbouncer unzip supervisor",
          "curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.1.2/node_exporter-1.1.2.linux-amd64.tar.gz",
          "tar -xvf node_exporter-1.1.2.linux-amd64.tar.gz",
          "sudo cp node_exporter-1.1.2.linux-amd64/node_exporter /usr/local/bin/node_exporter",
          "curl -LO https://github.com/prometheus-community/pgbouncer_exporter/releases/download/v0.4.0/pgbouncer_exporter-0.4.0.linux-amd64.tar.gz",
          "tar -xvf pgbouncer_exporter-0.4.0.linux-amd64.tar.gz",
          "sudo cp pgbouncer_exporter-0.4.0.linux-amd64/pgbouncer_exporter /usr/local/bin/pgbouncer_exporter",
          "curl -LO https://releases.hashicorp.com/vault/1.7.1/vault_1.7.1_linux_amd64.zip",
          "unzip vault_1.7.1_linux_amd64.zip",
          "sudo cp vault /usr/local/bin/vault",
          "curl -LO https://golang.org/dl/go1.16.4.linux-amd64.tar.gz",
          "sudo rm -rf /usr/local/go",
          "sudo tar -C /usr/local -xzf go1.16.4.linux-amd64.tar.gz",
          "export PATH=$PATH:/usr/local/go/bin",
          "go get github.com/deliveroo/pgbouncer-healthcheck",
          "sudo mv $(go env GOPATH)/bin/pgbouncer-healthcheck /usr/local/bin/pgbouncer-healthcheck",
          "echo ====== Clean up junks ======",
          "rm -f ./vault",
          "rm -f ./vault_1.7.1_linux_amd64.zip",
          "rm -rf ./pgbouncer_exporter-0.4.0.linux-amd64",
          "rm -f ./pgbouncer_exporter-0.4.0.linux-amd64.tar.gz",
          "rm -rf ./node_exporter-1.1.2.linux-amd64",
          "rm -f ./node_exporter-1.1.2.linux-amd64.tar.gz",
          "rm -f  go1.16.4.linux-amd64.tar.gz"
        ]
        max_retries = 3
    }

    post-processor "shell-local" {
        inline = ["echo Hello World from ${source.type}.${source.name}"]
    }
}