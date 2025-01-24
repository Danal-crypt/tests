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
RSYNC_OPTIONS="-avz --stats --exclude='*.tmp'"

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

    # Step 1: Fetch the password for the current hostname
    PASSWORD_OUTPUT=$(/opt/password/GetPassword object="${hostname}-splunk" -password 2>&1)
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Obtained password for $hostname"
        PASSWORD=$PASSWORD_OUTPUT
    else
        echo "[FAILURE] Could not obtain password for $hostname. Output: $PASSWORD_OUTPUT"
        continue
    fi

    # Step 2: Perform rsync dry-run to display what will be transferred
    echo "Running rsync dry-run for $hostname with stats..."
    sshpass -p "$PASSWORD" rsync $RSYNC_OPTIONS --dry-run \
        -e "ssh -o StrictHostKeyChecking=no" \
        "$LOCAL_SOURCE_DIR/" "${REMOTE_USER}@${hostname}:${REMOTE_DEST_DIR}/" 2>&1
    if [ $? -ne 0 ]; then
        echo "[FAILURE] Rsync dry-run failed for $hostname."
        continue
    fi
    echo "[SUCCESS] Dry-run completed for $hostname."

    # Step 3: Generate a random 4-digit number and prompt user for confirmation
    RANDOM_CODE=$((RANDOM % 9000 + 1000)) # Generate a 4-digit random number
    echo "If the above information looks correct, input the following code to proceed: $RANDOM_CODE"
    while true; do
        # Prompt user and read input
        echo -n "Enter the code to confirm the transfer for $hostname: "
        read -r user_input

        # Echo what the user entered
        echo "You entered: $user_input"

        if [[ "$user_input" == "$RANDOM_CODE" ]]; then
            echo "Code verified. Proceeding with actual rsync transfer for $hostname..."
            sshpass -p "$PASSWORD" rsync $RSYNC_OPTIONS \
                -e "ssh -o StrictHostKeyChecking=no" \
                "$LOCAL_SOURCE_DIR/" "${REMOTE_USER}@${hostname}:${REMOTE_DEST_DIR}/" 2>&1
            if [ $? -eq 0 ]; then
                echo "[SUCCESS] Rsync transfer completed for $hostname."
            else
                echo "[FAILURE] Rsync transfer failed for $hostname."
            fi
            break
        else
            echo "Invalid code. Please try again."
        fi
    done

done < "$HOST_FILE"

echo "Script completed."
