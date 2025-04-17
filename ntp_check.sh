#!/bin/bash

timestamp=$(date -Iseconds)
host=$(hostname)
source="ntp_status_linux"

# Timezone
timezone=$(timedatectl | awk -F ': ' '/Time zone/ {print $2}' | awk '{print $1}')

# NTP servers from chrony.conf
ntp_servers=$(grep -E '^server|^pool' /etc/chrony.conf 2>/dev/null | awk '{print $2}' | paste -sd "," -)

# System clock sync status
ntp_sync_status=$(timedatectl | awk -F ': ' '/System clock synchronized/ {print $2}')

# chronyd service status
chronyd_status=$(systemctl is-active chronyd 2>/dev/null)
chronyd_enabled=$(systemctl is-enabled chronyd 2>/dev/null)

# Output key-value header line
echo "timestamp=$timestamp host=$host timezone=$timezone ntp_servers=$ntp_servers chronyd_status=$chronyd_status chronyd_enabled=$chronyd_enabled time_in_sync=$ntp_sync_status source=$source"

# Now output chronyc tracking output as separate lines under a single field name
echo "tracking_raw="
chronyc tracking 2>/dev/null
