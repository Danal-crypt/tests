#!/bin/bash

# Define the paths and commands
declare -A services=(
    [splunk]="/opt/splunk/bin/splunk status"
    [caspida]="/opt/caspida/bin/Caspida status"
    [cribl]="/opt/cribl/bin/cribl status"
)

# Get current timestamp
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Check and output the status of each service
for service in "${!services[@]}"; do
    if [ -d "/opt/$service" ]; then
        status_output=$(${services[$service]} 2>&1)
        status_code=$?

        # Format the output for Splunk ingestion
        echo "timestamp=\"$timestamp\", service=\"$service\", status_code=\"$status_code\", output=\"$status_output\""
    else
        # If the service directory doesn't exist
        echo "timestamp=\"$timestamp\", service=\"$service\", status=\"not_installed\""
    fi
done
