#!/bin/bash

# ================================
# USAGE: ./testPorts.sh
# ================================

# Define list of hosts
HOSTS=("host1.example.com" "host2.example.com")

# Define list of ports
PORTS=(80 443 514)

# Protocol: "tcp" or "udp"
PROTOCOL="tcp"

# User info
USER=$(whoami)

# Timestamp function
timestamp() {
  date +"%Y-%m-%d %H:%M:%S.%3N %Z"
}

# Protocol flag for netcat
if [[ "$PROTOCOL" == "udp" ]]; then
  NCFLAG="-u"
else
  NCFLAG=""
fi

# Function to test a single host/port combo
test_connection() {
  local HOST=$1
  local PORT=$2
  echo "<$(timestamp)> $USER sending to $HOST port $PORT $PROTOCOL"
  echo "<$(timestamp)> $USER sending to $HOST port $PORT $PROTOCOL" | nc -v $NCFLAG "$HOST" "$PORT" &> >(sed "s/^/[$HOST:$PORT] /")
}

# Launch all tests in parallel
for HOST in "${HOSTS[@]}"; do
  for PORT in "${PORTS[@]}"; do
    test_connection "$HOST" "$PORT" &
  done
done

# Wait for all background jobs to complete
wait
echo "✅ All tests completed."
