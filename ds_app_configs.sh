#!/bin/bash

# Define the deployment-apps directory
DEPLOYMENT_APPS_DIR="$SPLUNK_HOME/etc/deployment-apps"

# Check if the user has provided the configuration file to search for
if [[ -z "$1" ]]; then
    echo "Usage: $0 <config_file_name_without_extension> [app_keyword]"
    echo "Example: $0 outputs (to search all apps for outputs.conf)"
    echo "Example: $0 outputs ueba (to search for outputs.conf in apps containing 'ueba')"
    exit 1
fi

# Define the configuration file to search for
CONFIG_FILE="$1.conf"

# Optional keyword to filter apps
APP_KEYWORD="$2"

# Check if the deployment-apps directory exists
if [[ ! -d "$DEPLOYMENT_APPS_DIR" ]]; then
    echo "Error: Deployment-apps directory does not exist: $DEPLOYMENT_APPS_DIR"
    exit 1
fi

# Loop through each app in the deployment-apps directory
echo "Searching for '$CONFIG_FILE' in apps under $DEPLOYMENT_APPS_DIR:"
if [[ -n "$APP_KEYWORD" ]]; then
    echo "Filtering apps by keyword: $APP_KEYWORD"
fi

for app_dir in "$DEPLOYMENT_APPS_DIR"/*; do
    # Skip if not a directory
    if [[ ! -d "$app_dir" ]]; then
        continue
    fi

    # Check if the app directory matches the optional keyword (if provided)
    app_name=$(basename "$app_dir")
    if [[ -n "$APP_KEYWORD" && "$app_name" != *"$APP_KEYWORD"* ]]; then
        continue
    fi

    # Check if the configuration file exists within the app (default or local)
    config_path_default="$app_dir/default/$CONFIG_FILE"
    config_path_local="$app_dir/local/$CONFIG_FILE"

    # Display contents if the file exists in default
    if [[ -f "$config_path_default" ]]; then
        echo "==== $config_path_default ===="
        cat "$config_path_default"
        echo ""
    fi

    # Display contents if the file exists in local
    if [[ -f "$config_path_local" ]]; then
        echo "==== $config_path_local ===="
        cat "$config_path_local"
        echo ""
    fi
done
