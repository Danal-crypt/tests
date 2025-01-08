#!/bin/bash

# Define the paths to the services and their commands
declare -A service_commands=(
    [splunk]="/opt/splunk/bin/splunk status"
    [caspida]="/app/caspida/bin/Caspida status"
    [cribl]="/opt/cribl/bin/cribl status"
)

# Define the mapping of hostnames to expected services
declare -A host_services=(
    [host1]="splunk caspida"
    [host2]="cribl"
    [host3]="splunk"
)

# Define ports associated with services
declare -A service_ports=(
    [splunk]="8089 9997"
    [cribl]="514"
    [caspida]="8443"
)

# Define log file locations for services
declare -A service_logs=(
    [splunk]="/opt/splunk/var/log/splunk/splunkd.log"
    [cribl]="/opt/cribl/log/cribl.log"
    [caspida]="/app/caspida/log/caspida.log"
)

# Define the output file
output_file="/var/log/service_status.log"

# Get the current timestamp and hostname
entry_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
hostname=$(hostname -s) # Short hostname

# Collect general system information
system_info="System uptime: $(uptime -p | sed 's/^up //')
Disk usage on /: $(df -h / | awk 'NR==2 {print $5}')
Memory usage: $(free -m | awk 'NR==2{printf "Used: %sMB, Free: %sMB", $3, $4}')
CPU load: $(top -bn1 | grep "load average" | awk '{printf "1-min: %s, 5-min: %s, 15-min: %s", $10, $11, $12}' | sed 's/,//g')"

# Collect the last 5 package updates
last_updates=$(rpm -qa --last | head -n 5 | awk '{printf "%s %s %s\n", $1, $2, $3}')

# Prepare service-specific information
service_info=""
expected_services=${host_services[$hostname]}

if [ -z "$expected_services" ]; then
    service_info="No services configured for hostname $hostname."
else
    for service in $expected_services; do
        command=${service_commands[$service]}
        if [ -x "$(dirname $command)" ]; then
            status_output=$($command 2>&1)
            status_code=$?
            service_info+="Service: $service
    Status Code: $status_code
    Output: $status_output
"
        else
            service_info+="Service: $service
    Status: not_installed_or_not_accessible
"
        fi

        # Check open ports for the service
        ports=${service_ports[$service]}
        if [ -n "$ports" ]; then
            for port in $ports; do
                port_status=$(netstat -tuln | grep ":$port" >/dev/null && echo "open" || echo "closed")
                service_info+="    Port $port: $port_status
"
            done
        fi

        # Append last 5 lines of service-specific logs
        log_file=${service_logs[$service]}
        if [ -f "$log_file" ]; then
            service_info+="    Last 5 lines of log:
$(tail -n 5 "$log_file" | sed 's/^/        /')
"
        else
            service_info+="    Log file not found: $log_file
"
        fi
    done
fi

# Combine all output into a single entry
output="Timestamp: $entry_timestamp
Hostname: $hostname

System Information:
$system_info

Last 5 Package Updates:
$last_updates

Service Information:
$service_info
"

# Write the output to the log file
echo "$output" >> $output_file
