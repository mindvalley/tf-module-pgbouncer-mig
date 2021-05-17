#!/bin/bash

# This script is meant to be run as the Startup Script of a Compute Instance
# while it's booting. Afterwards it performs the necessary api requests to login
# to a Vault cluster. At the end it also serves a simple webserver with a message
# read from Vault, for test purposes, so we can curl the response and test that
# the authentication example is working as expected.

set -e 

# Send the log output from this script to startup-script.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

function log {
  local -r message="$1"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "$timestamp $message"
}

# A retry function that attempts to run a command a number of times and returns the output
function retry {
  local -r cmd="$1"
  local -r description="$2"

  for i in $(seq 1 30); do
    log "$description"

    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    output=$(eval "$cmd") && exit_status=0 || exit_status=$?
    log "$output"
    if [[ $exit_status -eq 0 ]]; then
      echo "$output"
      return
    fi
    log "$description failed. Will sleep for 10 seconds and try again."
    sleep 10
  done;

  log "$description failed after 30 attempts."
  exit $exit_status
}

# ==========================================================
# BEGIN TO CONFIGURE THE INSTANCE
# ==========================================================

# Ensure the vault agent is configured with proper contents & templates
mkdir -p /etc/vault

cat <<EOF > /etc/vault/config.hcl
pid_file = "/tmp/vault.pid"

vault {
  address = "https://bunker.mindvalley.dev:8200"
  retry {
    num_retries = 5
  }
}

auto_auth {
  method "gcp" {
    config = {
      type = "gce"
      role = "${cluster_vault_role}"
    }
  }

cache {
  use_auto_auth_token = true
}

template {
  source = "/etc/vault/pgbouncer.ctmpl"
  destination = "/etc/pgbouncer/pgbouncer.ini"
}
EOF

# Ensure the supervisord's program are presented
## PgBouncer
cat <<EOF > /etc/supervisord/conf.d/10-pgbouncer
[program:pgbouncer]
command=/usr/sbin/pgbouncer
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=999
autostart=true
autorestart=unexpected
startsecs=10
startretries=3
exitcodes=0
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=postgres
serverurl=AUTO
EOF

## PgBouncer Exporter
cat <<EOF > 
[program:pgbouncer-exporter]
command=/usr/local/bin/pgbouncer_exporter --pgBouncer.connectionString="postgres://statuser:password@localhost:6432/pgbouncer?sslmode=disable"
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=999
autostart=true
autorestart=unexpected
startsecs=10
startretries=3
exitcodes=0
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=postgres
serverurl=AUTO