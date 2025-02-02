#!/bin/bash

# Define configurations for each hostname
declare -A host_configs=(
    [host1]="services=splunk,caspida ports=8089,9997,8443 partitions=/,/var"
    [host2]="services=cribl ports=514 partitions=/,/home"
    [host3]="services=splunk ports=8089 partitions=/"
)

# Define the paths to the services and their commands
declare -A service_commands=(
    [splunk]="/opt/splunk/bin/splunk status"
    [caspida]="/app/caspida/bin/Caspida status"
    [cribl]="/opt/cribl/bin/cribl status"
)

# Define log file locations for services
declare -A service_logs=(
    [splunk]="/opt/splunk/var/log/splunk/splunkd.log"
    [cribl]="/opt/cribl/log/cribl.log"
    [caspida]="/app/caspida/log/caspida.log"
)

# Define the output file
output_file="/var/log/service_status.json"

# Ensure the output directory exists
mkdir -p "$(dirname "$output_file")"

# Get the current timestamp and hostname
entry_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
hostname=$(hostname -s) # Short hostname

# Retrieve configuration for the current host
config=${host_configs[$hostname]}
if [ -z "$config" ]; then
    echo "{\"timestamp\": \"$entry_timestamp\", \"hostname\": \"$hostname\", \"error\": \"No configuration found for this host.\"}" > "$output_file"
    exit 1
fi

# Parse the configuration
services=$(echo "$config" | grep -oP 'services=\K[^ ]+')
ports=$(echo "$config" | grep -oP 'ports=\K[^ ]+')
partitions=$(echo "$config" | grep -oP 'partitions=\K[^ ]+')

# Collect partition information
partition_info="["
if [ -n "$partitions" ]; then
    for partition in $(echo "$partitions" | tr ',' ' '); do
        echo "Processing partition: $partition" >&2
        partition_data=$(df -h "$partition" 2>/dev/null | awk 'NR==2 {printf "\"size\":\"%s\", \"used\":\"%s\", \"available\":\"%s\", \"used_percentage\":\"%s\"", $2, $3, $4, $5}')
        if [ -n "$partition_data" ]; then
            partition_info+="{\"partition\": \"$partition\", $partition_data},"
        else
            echo "Partition data not found for: $partition" >&2
        fi
    done
    partition_info="${partition_info%,}]"
else
    partition_info="[]"
fi

system_info=$(cat <<EOF
{
    "uptime": "$(uptime -p | sed 's/^up //')",
    "partitions": $partition_info
}
EOF
)

# Collect the last 5 package updates
last_updates=$(rpm -qa --last | head -n 5 | awk '{printf "{\"package\":\"%s\", \"date\":\"%s %s %s %s\"},", $1, $2, $3, $4, $5}')
last_updates="[${last_updates%,}]"

# Prepare service-specific information
service_info="["
if [ -n "$services" ]; then
    for service in $(echo "$services" | tr ',' ' '); do
        echo "Processing service: $service" >&2
        command=${service_commands[$service]}
        if [ -x "$(command -v ${command%% *})" ]; then
            status_output=$($command 2>&1)
            status_code=$?
            log_file=${service_logs[$service]}
            if [ -f "$log_file" ]; then
                service_log=$(tail -n 10 "$log_file" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
            else
                service_log="Log file not found: $log_file"
            fi
            service_info+=$(cat <<EOF
{
    "service": "$service",
    "status_code": $status_code,
    "output": "$(echo $status_output | sed 's/"/\\"/g')",
    "log": "$service_log"
},
EOF
)
        else
            echo "Command not found or not executable: $command" >&2
            service_info+=$(cat <<EOF
{
    "service": "$service",
    "status": "not_installed_or_not_accessible"
},
EOF
)
        fi
    done
    service_info="${service_info%,}]"
else
    service_info="[]"
fi

# Prepare port-specific information
port_info="["
if [ -n "$ports" ]; then
    for port in $(echo "$ports" | tr ',' ' '); do
        echo "Processing port: $port" >&2
        port_status=$(timeout 5 netstat -tuln | grep ":$port" >/dev/null && echo "open" || echo "closed")
        port_info+="{\"port\": \"$port\", \"status\": \"$port_status\"},"
    done
    port_info="${port_info%,}]"
else
    port_info="[]"
fi

# Combine all output into a single JSON object
output=$(cat <<EOF
{
    "timestamp": "$entry_timestamp",
    "hostname": "$hostname",
    "system_info": $system_info,
    "last_updates": $last_updates,
    "services": $service_info,
    "ports": $port_info
}
EOF
)

# Write the output to the JSON file
echo "$output" > "$output_file"

echo "Script completed successfully. Output written to $output_file" >&2
