#!/bin/bash

# Check for root
if [[ $EUID -ne 0 ]]; then
	echo "This script must run as root."
	exit 1
fi

rm -rf .influxdb3
rm -f .env

rm -f influxdb3-explorer/config/config.json

docker compose down
docker ps --all