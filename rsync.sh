#!/bin/bash

# ------------------------
# Configurable Variables
# ------------------------

# Path to the file containing the list of hostnames
HOST_FILE="hosts.txt"

# Local source directory (must exist on the local machine)
LOCAL_SOURCE_DIR="/path/to/local/source"

# Remote destination directory
REMOTE_DEST_DIR="/path/to/remote/destination"

# rsync options (e.g., -avz for archive, verbose, compress)
RSYNC_OPTIONS="-avz --exclude='*.tmp'"

# Username for connecting to the remote servers
REMOTE_USER="splunk"

# ------------------------
# Script Logic
# ------------------------

# Validate the host file
if [[ ! -f "$HOST_FILE" ]]; then
    echo "[ERROR] Host file not found: $HOST_FILE"
    exit 1
fi

# Validate local source directory
if [[ ! -d "$LOCAL_SOURCE_DIR" ]]; then
    echo "[ERROR] Source directory not found: $LOCAL_SOURCE_DIR"
    exit 1
fi

# Process each hostname in the host file
while IFS= read -r hostname; do
    # Skip empty lines or lines with only whitespace
    [[ -z "$hostname" ]] && continue

    echo "Processing hostname: $hostname"

    # Fetch the password for the current hostname
    PASSWORD_OUTPUT=$(/opt/password/GetPassword object="${hostname}-splunk" -password 2>&1)
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Obtained password for $hostname"
        PASSWORD=$PASSWORD_OUTPUT
    else
        echo "[FAILURE] Could not obtain password for $hostname. Output: $PASSWORD_OUTPUT"
        continue
    fi

    # Perform rsync dry-run to display what will be transferred
    echo "Running rsync dry-run for $hostname..."
    sshpass -p "$PASSWORD" rsync $RSYNC_OPTIONS --dry-run "$LOCAL_SOURCE_DIR/" "${REMOTE_USER}@${hostname}:${REMOTE_DEST_DIR}/"
    if [ $? -ne 0 ]; then
        echo "[FAILURE] Rsync dry-run failed for $hostname. Skipping..."
        continue
    fi

    # Ask the user whether to proceed with the actual rsync transfer
    while true; do
        read -rp "Do you want to proceed with the actual rsync transfer for $hostname? (yes/no): " user_input
        user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]' | xargs) # Normalize input (lowercase + trim whitespace)
        if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
            echo "Proceeding with actual rsync transfer for $hostname..."
            sshpass -p "$PASSWORD" rsync $RSYNC_OPTIONS "$LOCAL_SOURCE_DIR/" "${REMOTE_USER}@${hostname}:${REMOTE_DEST_DIR}/"
            if [ $? -eq 0 ]; then
                echo "[SUCCESS] Rsync transfer completed for $hostname"
            else
                echo "[FAILURE] Rsync transfer failed for $hostname."
            fi
            break
        elif [[ "$user_input" == "no" || "$user_input" == "n" ]]; then
            echo "Skipping rsync transfer for $hostname."
            break
        else
            echo "Invalid input. Please enter 'yes' or 'no'."
        fi
    done

done < "$HOST_FILE"

echo "Script completed."
