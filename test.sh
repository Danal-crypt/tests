#!/bin/bash

# Editable section
HOSTS=("8.8.8.8" "1.1.1.1")
PORTS=("53" "443")
TRANSPORTS=("tcp" "udp")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

for HOST in "${HOSTS[@]}"; do
  for PORT in "${PORTS[@]}"; do
    for TRANSPORT in "${TRANSPORTS[@]}"; do
      CONNECTED="no"
      ERROR=""

      if [[ "$TRANSPORT" == "tcp" ]]; then
        OUTPUT=$(nc -z -w2 "$HOST" "$PORT" 2>&1)
        if [[ $? -eq 0 ]]; then
          CONNECTED="yes"
        else
          ERROR=$OUTPUT
        fi

      elif [[ "$TRANSPORT" == "udp" ]]; then
        OUTPUT=$(nc -z -u -w2 "$HOST" "$PORT" 2>&1)
        if [[ $? -eq 0 ]]; then
          CONNECTED="yes"
        else
          ERROR=$OUTPUT
        fi
      fi

      if [[ "$CONNECTED" == "yes" ]]; then
        echo "timestamp=\"$TIMESTAMP\" connected_host=\"$HOST\" connected_port=\"$PORT\" connected=\"$CONNECTED\" transport=\"$TRANSPORT\""
      else
        echo "timestamp=\"$TIMESTAMP\" connected_host=\"$HOST\" connected_port=\"$PORT\" connected=\"$CONNECTED\" transport=\"$TRANSPORT\" error=\"${ERROR//\"/\\\"}\""
      fi
    done
  done
done
