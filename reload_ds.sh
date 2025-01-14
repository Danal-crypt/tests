#!/bin/bash

# Usage: ./reload_ds.sh <serverclass_name>
# Example to reload a specific serverclass: ./reload_ds.sh Windows
# Example to reload the entire deployment server: ./reload_ds.sh ALL

# Placeholder for CyberArk token retrieval command
# Replace this placeholder with your actual command to fetch the token
TOKEN=$(# Insert your CyberArk command here to fetch the token)

# Check if the TOKEN variable was populated
if [[ -z "$TOKEN" ]]; then
  echo "Error: Failed to retrieve token. Please check your CyberArk command."
  exit 1
fi

# Check input argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <serverclass_name>"
  echo "Example: $0 Windows"
  echo "Example: $0 ALL (to reload the entire deployment server)"
  exit 1
fi

# Set serverclass_name
SERVERCLASS_NAME=$1

# Reload logic
if [[ "$SERVERCLASS_NAME" == "ALL" ]]; then
  # Reload the entire deployment server
  /opt/splunk/bin/splunk reload deploy-server -token "$TOKEN"
  if [[ $? -eq 0 ]]; then
    echo "Successfully reloaded the entire deployment server."
  else
    echo "Failed to reload the deployment server."
    exit 1
  fi
else
  # Reload a specific serverclass
  /opt/splunk/bin/splunk reload deploy-server -class "$SERVERCLASS_NAME" -token "$TOKEN"
  if [[ $? -eq 0 ]]; then
    echo "Successfully reloaded serverclass: $SERVERCLASS_NAME."
  else
    echo "Failed to reload serverclass: $SERVERCLASS_NAME."
    exit 1
  fi
fi
