#!/usr/bin/env bash
# sftp_log_mirror.sh
# Mirrors logs from two SFTP servers into /opt/logs for Splunk monitoring.
# Requires: openssh-clients (for sftp) and expect (usually preinstalled on RHEL).

set -euo pipefail

##############################################
# EDIT THESE VARIABLES
##############################################
HOSTS=("10.0.0.11" "10.0.0.22")
PORTS=("22" "22")
USERS=("user1" "user2")
PASSWORDS=("pass1" "pass2")
REMOTE_DIRS=("/var/log/app" "/var/log/otherapp")
TAGS=("srv1" "srv2")
LOCAL_ROOT="/opt/logs"
##############################################

mkdir -p "$LOCAL_ROOT"

for i in "${!HOSTS[@]}"; do
  HOST="${HOSTS[$i]}"
  PORT="${PORTS[$i]}"
  USER="${USERS[$i]}"
  PASS="${PASSWORDS[$i]}"
  REMOTE_DIR="${REMOTE_DIRS[$i]}"
  TAG="${TAGS[$i]}"
  LOCAL_DIR="$LOCAL_ROOT/$TAG"

  mkdir -p "$LOCAL_DIR"

  # Use expect to automate password entry for sftp
  expect <<EOF >/dev/null 2>&1
spawn sftp -P $PORT -o StrictHostKeyChecking=no $USER@$HOST
expect "password:"
send "$PASS\r"
expect "sftp>"
send "cd $REMOTE_DIR\r"
expect "sftp>"
send "lcd $LOCAL_DIR\r"
expect "sftp>"
send "get -r *\r"
expect "sftp>"
send "bye\r"
expect eof
EOF

done
