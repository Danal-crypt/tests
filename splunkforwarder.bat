#!/bin/bash

# Variables
SPLUNK_URL=""
SPLUNK_DIR="/opt/SplunkForwarder"
DEPLOYMENT_SERVER="<deployment-server>:<port>" # Replace with your actual deployment server and port
SPLUNK_USER="splunkforwarder"
SPLUNK_GROUP="splunkforwarder"

# Step 1: Create splunkforwarder user and group
echo "Creating user and group for Splunk..."
groupadd -r $SPLUNK_GROUP
useradd -r -g $SPLUNK_GROUP -d $SPLUNK_DIR -s /bin/bash $SPLUNK_USER

# Step 2: Download Splunk Universal Forwarder
echo "Downloading Splunk Universal Forwarder..."
wget -O /tmp/splunkforwarder.tgz $SPLUNK_URL

# Step 3: Create installation directory and extract Splunk
echo "Extracting Splunk to $SPLUNK_DIR..."
mkdir -p $SPLUNK_DIR
tar -xvf /tmp/splunkforwarder.tgz -C $SPLUNK_DIR --strip-components=1

# Step 4: Set ownership of Splunk installation directory
echo "Setting ownership of Splunk directory..."
chown -R $SPLUNK_USER:$SPLUNK_GROUP $SPLUNK_DIR

# Step 5: Disable port 8089 (management port)
echo "Disabling management port (8089)..."
sudo -u $SPLUNK_USER $SPLUNK_DIR/bin/splunk set splunkd-port 0 --accept-license --answer-yes --no-prompt

# Step 6: Set deployment server
echo "Configuring deployment server..."
sudo -u $SPLUNK_USER $SPLUNK_DIR/bin/splunk set deploy-poll $DEPLOYMENT_SERVER --accept-license --answer-yes --no-prompt

# Step 7: Enable boot-start with systemd and set AmbientCapabilities
echo "Enabling boot-start for Splunk Forwarder with systemd..."
$SPLUNK_DIR/bin/splunk enable boot-start -user $SPLUNK_USER --answer-yes --no-prompt --accept-license

# Add AmbientCapabilities to systemd service file
echo "Adding AmbientCapabilities to Splunk systemd service..."
sed -i '/^\[Service\]/a AmbientCapabilities=CAP_DAC_READ_SEARCH' /etc/systemd/system/splunkforwarder.service

# Step 8: Start the Splunk Forwarder service
echo "Starting Splunk Forwarder service..."
systemctl daemon-reload
systemctl start splunkforwarder

# Cleanup
rm /tmp/splunkforwarder.tgz

echo "Splunk Universal Forwarder installation complete."
