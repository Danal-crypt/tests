#!/bin/bash

# Editable Targets
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
        OUTPUT=$(nc -zv -w2 "$HOST" "$PORT" 2>&1)
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 0 ]]; then
          CONNECTED="yes"
        else
          ERROR="$OUTPUT"
        fi

      elif [[ "$TRANSPORT" == "udp" ]]; then
        OUTPUT=$(echo | nc -zvu -w2 "$HOST" "$PORT" 2>&1)
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 0 ]]; then
          CONNECTED="yes"
        else
          ERROR="$OUTPUT"
        fi
      fi

      # Clean up quotes in error for Splunk-friendly output
      ERROR="${ERROR//\"/\\\"}"

      if [[ "$CONNECTED" == "yes" ]]; then
        echo "timestamp=\"$TIMESTAMP\" connected_host=\"$HOST\" connected_port=\"$PORT\" connected=\"$CONNECTED\" transport=\"$TRANSPORT\""
      else
        echo "timestamp=\"$TIMESTAMP\" connected_host=\"$HOST\" connected_port=\"$PORT\" connected=\"$CONNECTED\" transport=\"$TRANSPORT\" error=\"$ERROR\""
      fi
    done
  done
done
