#!/bin/bash

# Timestamp and host
timestamp=$(date -Iseconds)
host=$(hostname)
source="ntp_status_linux"

# Timezone
timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')

# NTP server(s) from chrony.conf
ntp_servers=$(grep -E '^server|^pool' /etc/chrony.conf | awk '{print $2}' | paste -sd "," -)

# Is system clock synchronized?
ntp_sync_status=$(timedatectl | grep "System clock synchronized" | awk '{print $4}')

# Is chronyd active and enabled?
chronyd_status=$(systemctl is-active chronyd)
chronyd_enabled=$(systemctl is-enabled chronyd)

# Chrony tracking data (offset, stratum, ref ID)
tracking=$(chronyc tracking)
stratum=$(echo "$tracking" | grep -i "Stratum" | awk '{print $2}')
ref_source=$(echo "$tracking" | grep -i "Reference ID" | awk '{print $3}')
offset=$(echo "$tracking" | grep -i "Last offset" | awk '{print $3,$4}')

# Output in Splunk-friendly key-value format
echo "timestamp=$timestamp host=$host timezone=$timezone ntp_servers=$ntp_servers chronyd_status=$chronyd_status chronyd_enabled=$chronyd_enabled time_in_sync=$ntp_sync_status stratum=$stratum ref_source=$ref_source offset=\"$offset\" source=$source"
