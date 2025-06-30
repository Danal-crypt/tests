#!/bin/bash
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

# Loop through hosts and ports
for HOST in "${HOSTS[@]}"; do
  for PORT in "${PORTS[@]}"; do
    echo "<$(timestamp)> $HOST $USER sending to $HOST port $PORT $PROTOCOL"
    echo "<$(timestamp)> $HOST $USER sending to $HOST port $PORT $PROTOCOL" | nc -v $NCFLAG "$HOST" "$PORT"
    echo "------------------------------------------------------------"
  done
done
