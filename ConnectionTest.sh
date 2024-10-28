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




| rex max_match=0 "(?<host_status>connected_[^=]+=(Yes|No))"
| mvexpand host_status
| rex field=host_status "(?<hostname>connected_[^=]+)=(?<status>(Yes|No))"
| eval hostname = replace(hostname, "connected_", "")

| rex max_match=0 "(?<host_details>details_[^=]+=\"[^\"]+\")"
| mvexpand host_details
| rex field=host_details "(?<hostname_details>details_[^=]+)=\"(?<details>[^\"]+)\""
| eval hostname_details = replace(hostname_details, "details_", "")

| where hostname=hostname_details
| stats values(status) as Status, values(details) as Details by host, hostname
| eval ConnectionStatus = if(like(details, "%Operation not permitted%"), "Ping not permitted", if(Status="Yes", "Connected", "Not Connected"))
| table host hostname ConnectionStatus Details
