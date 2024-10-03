#!/bin/bash

# This script scans specified directories for SSL/TLS certificates (.pem, .crt, .cer, .key) 
# and checks their expiration status. It also searches .conf files in the same directories
# for any references to these certificates. The script outputs information about each 
# certificate, including the issuer, subject, SAN (Subject Alternative Name), start date,
# expiration date, and the status of the certificate ("expired", "expiring_within_30_days", "ok").
# If a certificate is referenced in any .conf files, the script lists those files.
# The script excludes specified directories from the scan and also will not display results of non existant directories.

# Set current time in seconds and calculate 30 days in seconds
today=$(date +%s)
thirty_days=$((30 * 24 * 60 * 60))

# Directories to search for certificates and .conf files
directories_to_scan=("/opt/*") # Modify as needed

# Directories to exclude from the search
excluded_dirs=("/path/to/exclude1" "/path/to/exclude2") # Modify as needed

# Function to check if the file is a certificate or a key
is_certificate() {
    local file="$1"
    openssl x509 -noout -in "$file" 2>/dev/null
}

# Function to search .conf files for references to a certificate file
find_conf_references() {
    local cert_file="$1"
    local conf_references=""
    
    # Use the same directories to scan for certificates and .conf file references
    for dir in "${directories_to_scan[@]}"; do
        # Skip if directory doesn't exist
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        # Find all .conf files in the directory and search for references to the cert file
        conf_files=$(find "$dir" -type f -name "*.conf" 2>/dev/null | xargs grep -l "$cert_file" 2>/dev/null)

        # Append the conf files that reference the cert file to conf_references
        if [[ -n "$conf_files" ]]; then
            if [[ -n "$conf_references" ]]; then
                conf_references="$conf_references, $conf_files"
            else
                conf_references="$conf_files"
            fi
        fi
    done

    # Return "null" if no conf references are found
    if [[ -z "$conf_references" ]]; then
        echo "null"
    else
        echo "$conf_references"
    fi
}

# Function to check expiration date of a certificate and gather information
check_certificates() {
    local cert_file="$1"
    local expiration_date
    local cert_start_date
    local expiration_in_seconds
    local time_until_expiration
    local status
    local issuer
    local subject
    local san
    local referencing_conf_files

    # Check if the file is a valid certificate
    if ! is_certificate "$cert_file"; then
        echo "host=$(hostname), cert_file=\"$cert_file\", status=invalid_or_key_file"
        return
    fi

    # Extract expiration date using openssl
    expiration_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | sed 's/notAfter=//')

    # Extract the start date of the certificate
    cert_start_date=$(openssl x509 -startdate -noout -in "$cert_file" 2>/dev/null | sed 's/notBefore=//')

    # Extract Subject Alternative Names (SAN)
    san=$(openssl x509 -in "$cert_file" -noout -text | grep -A 1 "Subject Alternative Name" | tail -1 | tr -d ',')
    if [[ -z "$san" ]]; then
        san="null"
    fi

    # Extract issuer and subject information
    issuer=$(openssl x509 -in "$cert_file" -noout -issuer)
    if [[ -z "$issuer" ]]; then
        issuer="null"
    fi

    subject=$(openssl x509 -in "$cert_file" -noout -subject)
    if [[ -z "$subject" ]]; then
        subject="null"
    fi

    # Search for references to the certificate in .conf files
    referencing_conf_files=$(find_conf_references "$cert_file")

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
    echo "host=$(hostname), cert_file=\"$cert_file\", issuer=\"$issuer\", subject=\"$subject\", san=\"$san\", cert_start_date=\"$cert_start_date\", expiration_date=\"$expiration_date\", status=$status, referencing_conf_files=\"$referencing_conf_files\""
}

# Build exclude conditions for find
exclude_conditions=()
for exclude_dir in "${excluded_dirs[@]}"; do
    exclude_conditions+=(! -path "$exclude_dir/*")
done

# Search for certificate files in the specified directories, excluding specified directories
for dir in "${directories_to_scan[@]}"; do
    # Expand directories containing wildcards but treat them as directories and not wildcard-expanded
    expanded_dirs=$(eval echo "$dir")

    # Check each expanded directory
    for expanded_dir in $expanded_dirs; do
        echo "Checking directory: $expanded_dir"

        # Skip directories that don't exist
        if [[ ! -d "$expanded_dir" ]]; then
            echo "Directory does not exist: $expanded_dir"
            continue
        fi

        find "$expanded_dir" "${exclude_conditions[@]}" -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.cer" -o -name "*.key" \) -print | while read cert_file; do
            check_certificates "$cert_file"
        done
    done
done
