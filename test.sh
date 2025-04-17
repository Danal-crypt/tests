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
      MESSAGE=""
      ERROR=""

      if [[ "$TRANSPORT" == "tcp" ]]; then
        OUTPUT=$(nc -zv -w2 "$HOST" "$PORT" 2>&1)
        if echo "$OUTPUT" | grep -qi "connected to"; then
          CONNECTED="yes"
          MESSAGE="$OUTPUT"
        else
          ERROR="$OUTPUT"
        fi

      elif [[ "$TRANSPORT" == "udp" ]]; then
        OUTPUT=$(echo | nc -zvuw2 "$HOST" "$PORT" 2>&1)
        if echo "$OUTPUT" | grep -qi "succeeded"; then
          CONNECTED="yes"
          MESSAGE="$OUTPUT"
        else
          ERROR="$OUTPUT"
        fi
      fi

      # Clean strings for Splunk-safe output
      ERROR="${ERROR//\"/\\\"}"
      MESSAGE="${MESSAGE//\"/\\\"}"

      if [[ "$CONNECTED" == "yes" ]]; then
        echo "timestamp=\"$TIMESTAMP\" connected_host=\"$HOST\" connected_port=\"$PORT\" connected=\"yes\" transport=\"$TRANSPORT\" message=\"$MESSAGE\""
      else
        echo "timestamp=\"$TIMESTAMP\" connected_host=\"$HOST\" connected_port=\"$PORT\" connected=\"no\" transport=\"$TRANSPORT\" error=\"$ERROR\""
      fi
    done
  done
done
