#!/bin/bash

# ------------------------
# Configurable Variables
# ------------------------

HOST_FILE="hosts.txt"
LOCAL_SOURCE_DIR="/path/to/local/source"
REMOTE_DEST_DIR="/path/to/remote/destination"
RSYNC_OPTIONS="-avz --stats --exclude='*.tmp'"
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

while IFS= read -r hostname; do
    [[ -z "$hostname" ]] && continue
    echo "Processing hostname: $hostname"

    # Step 1: Fetch the password for the current hostname
    PASSWORD_OUTPUT=$(/opt/password/GetPassword object="${hostname}-splunk" -password 2>&1)
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Obtained password for $hostname"
        PASSWORD=$PASSWORD_OUTPUT
    else
        echo "[FAILURE] Could not obtain password for $hostname."
        continue
    fi

    # Step 2: Perform rsync dry-run to display what will be transferred
    echo "Running rsync dry-run for $hostname with stats..."
    sshpass -p "$PASSWORD" rsync $RSYNC_OPTIONS --dry-run \
        -e "ssh -o StrictHostKeyChecking=no" \
        "$LOCAL_SOURCE_DIR/" "${REMOTE_USER}@${hostname}:${REMOTE_DEST_DIR}/"
    if [ $? -ne 0 ]; then
        echo "[FAILURE] Rsync dry-run failed for $hostname."
        continue
    fi
    echo "[SUCCESS] Dry-run completed for $hostname."

    # Step 3: Generate a random 4-digit number and prompt user for confirmation
    RANDOM_CODE=$((RANDOM % 9000 + 1000))
    echo "If the above information looks correct, input the following code to proceed: $RANDOM_CODE"
    while true; do
        # Use /dev/tty to ensure proper user input handling
        echo -n "Enter the code to confirm the transfer for $hostname: " > /dev/tty
        read -r user_input < /dev/tty

        if [[ -z "$user_input" ]]; then
            echo "No input detected. Please enter the code." > /dev/tty
            continue
        fi

        echo "You entered: $user_input" > /dev/tty

        if [[ "$user_input" == "$RANDOM_CODE" ]]; then
            echo "Code verified. Proceeding with actual rsync transfer for $hostname..." > /dev/tty
            sshpass -p "$PASSWORD" rsync $RSYNC_OPTIONS \
                -e "ssh -o StrictHostKeyChecking=no" \
                "$LOCAL_SOURCE_DIR/" "${REMOTE_USER}@${hostname}:${REMOTE_DEST_DIR}/"
            if [ $? -eq 0 ]; then
                echo "[SUCCESS] Rsync transfer completed for $hostname." > /dev/tty
            else
                echo "[FAILURE] Rsync transfer failed for $hostname." > /dev/tty
            fi
            break
        else
            echo "Invalid code. Please try again." > /dev/tty
        fi
    done

done < "$HOST_FILE"

echo "Script completed."
