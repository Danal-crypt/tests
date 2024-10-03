#!/bin/bash

# Set current time in seconds and calculate 30 days in seconds
today=$(date +%s)
thirty_days=$((30 * 24 * 60 * 60))

# Function to check if the file is a certificate or a key
is_certificate() {
    local file="$1"
    openssl x509 -noout -in "$file" 2>/dev/null
}

# Function to check expiration date of a certificate and gather information
check_certificates() {
    local cert_file="$1"
    local expiration_date
    local not_before
    local expiration_in_seconds
    local time_until_expiration
    local status
    local issuer
    local subject
    local san

    # Check if the file is a valid certificate
    if ! is_certificate "$cert_file"; then
        echo "host=$(hostname), cert_file=\"$cert_file\", status=invalid_or_key_file"
        return
    fi

    # Extract expiration date using openssl
    expiration_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | sed 's/notAfter=//')

    # Extract the start date of the certificate
    not_before=$(openssl x509 -startdate -noout -in "$cert_file" 2>/dev/null | sed 's/notBefore=//')

    # Extract Subject Alternative Names (SAN)
    san=$(openssl x509 -in "$cert_file" -noout -text | grep -A 1 "Subject Alternative Name" | tail -1 | tr -d ',')

    # Extract issuer and subject information
    issuer=$(openssl x509 -in "$cert_file" -noout -issuer)
    subject=$(openssl x509 -in "$cert_file" -noout -subject)

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

    # Output key-value pairs for Splunk with the relevant fields
    echo "host=$(hostname), cert_file=\"$cert_file\", issuer=\"$issuer\", subject=\"$subject\", san=\"$san\", not_before=\"$not_before\", expiration_date=\"$expiration_date\", status=$status"
}

# Array to hold directories to be excluded
excluded_dirs=("/path/to/exclude1" "/path/to/exclude2") # Modify as needed
exclude_conditions=()

# Build exclude conditions for find
for exclude_dir in "${excluded_dirs[@]}"; do
    exclude_conditions+=(! -path "$exclude_dir/*")
done

# Directories to search for certificates
directories=("/opt/splunk*" "/opt/caspida/" "/opt/cribl/*")

# Search for certificate files in the specified directories, excluding specified directories
for dir in "${directories[@]}"; do
    find $dir "${exclude_conditions[@]}" -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.cer" -o -name "*.key" \) -print | while read cert_file; do
        check_certificates "$cert_file"
    done
done
