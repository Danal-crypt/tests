#!/bin/bash

# Variables
SPLUNK_URL="https://download.splunk.com/products/universalforwarder/releases/9.3.1/linux/splunkforwarder-9.3.1-ae6821dc8e49-Linux-x86_64.tgz"
SPLUNK_DIR="/opt/SplunkForwarder"
DEPLOYMENT_SERVER="<deployment-server>:<port>" # Replace with your actual deployment server and port
SPLUNK_USER="<user>"  # Replace with the desired user (e.g., splunk)
SPLUNK_GROUP="<group>"  # Replace with the desired group (e.g., splunk)

# Step 1: Download Splunk Universal Forwarder
echo "Downloading Splunk Universal Forwarder..."
wget -O /tmp/splunkforwarder.tgz $SPLUNK_URL

# Step 2: Create installation directory and extract Splunk
echo "Extracting Splunk to $SPLUNK_DIR..."
mkdir -p $SPLUNK_DIR
tar -xvf /tmp/splunkforwarder.tgz -C $SPLUNK_DIR --strip-components=1

# Step 3: Modify server.conf to disable default management port (8089)
echo "Disabling management port (8089) in server.conf..."
mkdir -p $SPLUNK_DIR/etc/system/local
cat <<EOL > $SPLUNK_DIR/etc/system/local/server.conf
[httpServer]
disableDefaultPort = true
EOL

# Step 4: Set deployment server
echo "Configuring deployment server..."
$SPLUNK_DIR/bin/splunk set deploy-poll $DEPLOYMENT_SERVER --accept-license --answer-yes --no-prompt

# Step 5: Enable boot-start with specific user and group
echo "Enabling Splunk Forwarder to start at boot with user and group..."
$SPLUNK_DIR/bin/splunk enable boot-start -user $SPLUNK_USER -group $SPLUNK_GROUP

# Step 6: Start Splunk Forwarder
echo "Starting Splunk Forwarder..."
$SPLUNK_DIR/bin/splunk start --accept-license --answer-yes --no-prompt

# Cleanup
rm /tmp/splunkforwarder.tgz

echo "Splunk Universal Forwarder installation complete."
