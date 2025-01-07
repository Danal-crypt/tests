#!/bin/bash

# Define services with their specific paths and status commands
declare -A services=(
    [splunk]="/opt/splunk/bin/splunk status"
    [caspida]="/app/caspida/bin/Caspida status"
    [cribl]="/opt/cribl/bin/cribl status"
)

# Get current timestamp
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Check and output the status of each service
for service in "${!services[@]}"; do
    # Extract the command and path
    service_command=${services[$service]}
    service_path=$(dirname "$service_command")

    if [ -d "$service_path" ]; then
        status_output=$($service_command 2>&1)
        status_code=$?

        # Format the output for Splunk ingestion
        echo "timestamp=\"$timestamp\", service=\"$service\", location=\"$service_path\", status_code=\"$status_code\", output=\"$status_output\""
    else
        # If the directory for the service does not exist
        echo "timestamp=\"$timestamp\", service=\"$service\", status=\"not_installed\""
    fi
done
