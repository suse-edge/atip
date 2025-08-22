#!/bin/bash

set -euo pipefail

BASEDIR="$(dirname "$0")"
source ${BASEDIR}/basic-setup.sh

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Function to wait for ${KUBECTL} get nodes to succeed (API server readiness)
wait_for_api_server() {
  local timeout=300  # 5 minutes
  local start_time=$(date +%s)
  while true; do
    if ${KUBECTL} get nodes &> /dev/null; then
      echo "API server is ready."
      return 0
    fi
    local current_time=$(date +%s)
    if [ $((current_time - start_time)) -ge $timeout ]; then
      echo "Timeout waiting for API server."
      exit 1
    fi
    sleep 10
  done
}

# Wait for API server to be ready
wait_for_api_server

NODE_NAME="$(hostname)"
#NODE_NAME="edge-mgmt-cplane-1"
LAST_RESTART_TIME=0
COOLDOWN=300  # 5 minutes in seconds

while true; do
  CURRENT_TIME=$(date +%s)
  
  # Extract node conditions using ${KUBECTL}
  READY_STATUS=$(${KUBECTL} get node $NODE_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  NET_UNAVAILABLE_STATUS=$(${KUBECTL} get node $NODE_NAME -o jsonpath='{.status.conditions[?(@.type=="NetworkUnavailable")].status}')
  
  # Check if the node is ready
  if [ "$READY_STATUS" == "True" ]; then
    echo "$(date): Node is ready. Exiting."
    exit 0

  # Check if all required conditions are met
  elif [ "$READY_STATUS" == "False" ] && [ "$NET_UNAVAILABLE_STATUS" == "False" ]; then
    # Check if enough time has passed since the last restart
    if [ $((CURRENT_TIME - LAST_RESTART_TIME)) -gt $COOLDOWN ]; then
      echo "$(date): Detected stuck state: NotReady with NetworkUnavailable=False and CNIIsUp. Restarting rke2-server."
      systemctl restart rke2-server
      LAST_RESTART_TIME=$CURRENT_TIME
      exit 0
    else
      echo "$(date): Stuck state detected, but within cooldown period. Waiting."
    fi
  else
    echo "$(date): Node is not in stuck state."
  fi
  
  # Sleep for 10 seconds before checking again
  sleep 10
done