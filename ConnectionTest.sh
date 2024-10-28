#!/bin/bash

# List of heavy forwarder hosts
HOSTS=("hf1" "hf2" "hf3")  # Replace with hostnames of Heavy Forwarders, hostname only or FQDN will work

# Function to check connection for each host
check_connection() {
    local host="$1"
    local ping_output
    local nslookup_output
    local connected="Yes"
    local details=""

    # Ping the host
    ping_output=$(ping -c 1 "$host" 2>&1)
    if [[ $? -ne 0 ]]; then
        connected="No"
    fi
    details+="[Ping Output for $host]\n$ping_output\n"

    # Perform nslookup
    nslookup_output=$(nslookup "$host" 2>&1)
    if [[ $? -ne 0 ]]; then
        connected="No"
    fi
    details+="[Nslookup Output for $host]\n$nslookup_output\n"

    # Add connection status for each host
    OUTPUT="${OUTPUT} connected_${host}=${connected}"

    # Append the details with real line breaks
    OUTPUT="${OUTPUT} details_${host}=\"${details}\""
}

# Iterate over each host and check connection
for host in "${HOSTS[@]}"; do
    check_connection "$host"
done

# Output to stdout for Splunk ingestion
echo -e "$OUTPUT"
