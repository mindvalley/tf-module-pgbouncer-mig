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

cat <<EOF > /etc/vault/pgbouncer-userlist.ctmpl
"statsuser" = "somereallyfakestringthatdoesnothaveanymeaningatall"
%{ for db in enabled_databases }
{{ with secret "${db.password_vault_secret_path}" }}
"${db.username}" = "{{ .Data.postgres_db_password }}"
{{ end }}
%{ endfor ~}
EOF

# Create needed PgBouncer configuration files
cat <<EOF > /etc/pgbouncer/pgbouncer.ini
[databases]
%{ for db in enabled_databases }
${db.name} = host=${db.host} port=${db.port} dbname=${db.name} pool_size=${db.pool_size} user=${db.username}
%{ endfor ~}

[pgbouncer]
listen_port=${pgbouncer_config.listen_port}
listen_addr=${pgbouncer_config.listen_addr}
max_client_conn=${pgbouncer_config.max_client_conn}
unix_socket_dir=/tmp
auth_file=/etc/pgbouncer/userlist.txt
auth_hba_file=/etc/pgbouncer/pg_hba.conf
auth_type=hba
stats_users=statsuser
pool_mode=transaction
client_tls_sslmode=disable
ignore_startup_parameters = extra_float_digits
stats_period=10
syslog=1
EOF

cat <<EOF > /etc/pgbouncer/pg_hba.conf
# Allow any user on the local system to connect to any database with
# any database user name using Unix-domain sockets (the default for local
# connections).
#
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             statsuser                                     trust
host    all             all              0.0.0.0/0                       md5
EOF

# Create Vault agent config

cat <<EOF > /etc/vault/config.hcl
pid_file = "/tmp/vault.pid"

vault {
  address = "${vault_config.vault_server_address}"
  tls_skip_verify = "${vault_config.tls_skip_verify}"
  retry {
    num_retries = 5
  }
}

auto_auth {
  method "gcp" {
    config = {
      type = "gce"
      role = "${vault_config.vault_cluster_role}"
    }
  }
}

template {
  source = "/etc/vault/pgbouncer-userlist.ctmpl"
  destination = "/etc/pgbouncer/userlist.txt"
}
EOF

# Ensure the supervisord's program are presented
## PgBouncer
cat <<EOF > /etc/supervisor/conf.d/10-pgbouncer.conf
[program:pgbouncer]
command=/usr/sbin/pgbouncer /etc/pgbouncer/pgbouncer.ini
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=10
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
stdout_syslog=true
stderr_syslog=true
EOF

## PgBouncer Exporter
cat <<EOF > /etc/supervisor/conf.d/11-pgbouncer-exporter.conf
[program:pgbouncer-exporter]
command=/usr/local/bin/pgbouncer_exporter --pgBouncer.connectionString="postgresql:///pgbouncer?host=/tmp&port=6432&sslmode=disable&user=statsuser"
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=11
autostart=true
autorestart=unexpected
startsecs=10
startretries=5
exitcodes=0
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=postgres
serverurl=AUTO
stdout_syslog=true
stderr_syslog=true
EOF

## PgBouncer Healthcheck
cat <<EOF > /etc/supervisor/conf.d/12-pgbouncer-health-check.conf
[program:pgbouncer-healthcheck]
command=/usr/local/bin/pgbouncer-healthcheck
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=12
autostart=true
autorestart=unexpected
startsecs=10
startretries=5
exitcodes=0
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=postgres
serverurl=AUTO
stdout_syslog=true
stderr_syslog=true
environment=CONNSTR="host=/tmp port=6432 user=statsuser dbname=pgbouncer sslmode=disable",ENHANCED_CHECK="true"
EOF

## Node-Exporter
cat <<EOF > /etc/supervisor/conf.d/13-node-exporter.conf
[program:node-exporter]
command=/usr/local/bin/node_exporter
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=13
autostart=true
autorestart=unexpected
startsecs=10
startretries=5
exitcodes=0
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=nobody
serverurl=AUTO
stdout_syslog=true
stderr_syslog=true
EOF

## Vautl Agent
cat << EOF > /etc/supervisor/conf.d/14-vault.conf
[program:vault-agent]
command=/usr/local/bin/vault agent -config=/etc/vault/config.hcl
process_name=%(program_name)s
numprocs=1
directory=/tmp
umask=022
priority=1
autostart=true
autorestart=unexpected
startsecs=10
startretries=5
exitcodes=0
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=root
serverurl=AUTO
stdout_syslog=true
stderr_syslog=true
EOF

# Restart services
retry "systemctl stop pgbouncer" "Stop Pgbouncer"
retry "systemctl disable pgbouncer" "Disable Pgbouncer from systemd"
retry "systemctl restart supervisor" "Restart Supervisor"