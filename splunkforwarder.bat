#!/bin/bash

# Variables
SPLUNK_URL="https://download.splunk.com/products/universalforwarder/releases/9.3.1/linux/splunkforwarder-9.3.1-ae6821dc8e49-Linux-x86_64.tgz"
SPLUNK_DIR="/opt/SplunkForwarder"
DEPLOYMENT_SERVER="<deployment-server>:<port>" # Replace with your actual deployment server and port

# Step 1: Download Splunk Universal Forwarder
echo "Downloading Splunk Universal Forwarder..."
wget -O /tmp/splunkforwarder.tgz $SPLUNK_URL

# Step 2: Create installation directory and extract Splunk
echo "Extracting Splunk to $SPLUNK_DIR..."
mkdir -p $SPLUNK_DIR
tar -xvf /tmp/splunkforwarder.tgz -C $SPLUNK_DIR --strip-components=1

# Step 3: Disable port 8089 (management port)
echo "Disabling management port (8089)..."
$SPLUNK_DIR/bin/splunk set splunkd-port 0 --accept-license --answer-yes --no-prompt

# Step 4: Set deployment server
echo "Configuring deployment server..."
$SPLUNK_DIR/bin/splunk set deploy-poll $DEPLOYMENT_SERVER --accept-license --answer-yes --no-prompt

# Step 5: Set permissions for cap_dac_read_search
echo "Setting capabilities for Splunk Forwarder..."
setcap 'cap_dac_read_search=ep' $SPLUNK_DIR/bin/splunk

# Step 6: Start Splunk Forwarder and enable at boot
echo "Starting Splunk Forwarder..."
$SPLUNK_DIR/bin/splunk start --accept-license --answer-yes --no-prompt

echo "Enabling Splunk Forwarder to start at boot..."
$SPLUNK_DIR/bin/splunk enable boot-start

# Cleanup
rm /tmp/splunkforwarder.tgz

echo "Splunk Universal Forwarder installation complete."
