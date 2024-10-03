#!/bin/bash

# Set current time in seconds and calculate 30 days in seconds
today=$(date +%s)
thirty_days=$((30 * 24 * 60 * 60))

# Function to check expiration date of a certificate and gather information
check_certificates() {
    local cert_file="$1"
    local expiration_date
    local expiration_in_seconds
    local time_until_expiration
    local status
    local cert_type="unknown"
    local issuer
    local subject
    local serial
    local signature_algorithm
    local public_key_info
    local fingerprint
    local key_usage
    local ext_key_usage

    # Extract expiration date using openssl
    expiration_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | sed 's/notAfter=//')

    # Extract Key Usage and Extended Key Usage
    key_usage=$(openssl x509 -in "$cert_file" -noout -text | grep -A 1 'Key Usage' | tail -1)
    ext_key_usage=$(openssl x509 -in "$cert_file" -noout -text | grep -A 1 'Extended Key Usage' | tail -1)

    # Extract additional information
    issuer=$(openssl x509 -in "$cert_file" -noout -issuer)
    subject=$(openssl x509 -in "$cert_file" -noout -subject)
    serial=$(openssl x509 -in "$cert_file" -noout -serial)
    signature_algorithm=$(openssl x509 -in "$cert_file" -noout -text | grep 'Signature Algorithm' | head -1)
    public_key_info=$(openssl x509 -in "$cert_file" -noout -text | grep 'Public Key Algorithm' -A 10 | tr '\n' ' ')
    fingerprint=$(openssl x509 -in "$cert_file" -noout -sha256 -fingerprint)

    # Determine the certificate type based on key usage
    if echo "$ext_key_usage" | grep -q 'TLS Web Server Authentication'; then
        cert_type="server"
    elif echo "$ext_key_usage" | grep -q 'TLS Web Client Authentication'; then
        cert_type="client"
    elif openssl x509 -in "$cert_file" -noout -issuer -subject | grep -q 'issuer=subject'; then
        cert_type="root"
    elif echo "$key_usage" | grep -q 'Certificate Sign'; then
        cert_type="intermediate"
    fi

    # Check if the certificate has a valid expiration date
    if [[ -n "$expiration_date" ]]; then
        # Convert expiration date to seconds since epoch
        expiration_in_seconds=$(date -d "$expiration_date" +%s)

        # Calculate the remaining time before expiration
        time_until_expiration=$((expiration_in_seconds - today))

        # Determine the status based on time until expiration
        if [[ $time_until_expiration -lt 0 ]]; then
            status="expired"
        elif [[ $time_until_expiration -le $thirty_days ]]; then
            status="expiring_within_30_days"
        else
            status="ok"
        fi
    else
        status="invalid_certificate"
    fi

    # Output key-value pairs for Splunk with all the gathered data
    echo "host=$(hostname), cert_file=\"$cert_file\", expiration_date=\"$expiration_date\", cert_type=$cert_type, key_usage=\"$key_usage\", ext_key_usage=\"$ext_key_usage\", issuer=\"$issuer\", subject=\"$subject\", serial=\"$serial\", signature_algorithm=\"$signature_algorithm\", public_key_info=\"$public_key_info\", fingerprint=\"$fingerprint\", status=$status"
}

# Array to hold directories to be excluded
excluded_dirs=("/path/to/exclude1" "/path/to/exclude2") # Modify as needed
exclude_conditions=()

# Build exclude conditions for find
for exclude_dir in "${excluded_dirs[@]}"; do
    exclude_conditions+=(! -path "$exclude_dir/*")
done

# Directories to search for certificates
directories=("/opt/")

# Search for certificate files in the specified directories, excluding specified directories
for dir in "${directories[@]}"; do
    find $dir "${exclude_conditions[@]}" -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.cer" \) -print | while read cert_file; do
        check_certificates "$cert_file"
    done
done
