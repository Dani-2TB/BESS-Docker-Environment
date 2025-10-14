#!/bin/bash
# Check for root
if [[ $EUID -ne 0 ]]; then
	echo "This script must run as root."
	exit 1
fi

# Setup persistent directory with proper permissions
mkdir -p .influxdb3/data .influxdb3/plugins
chown -R 1500:1500 .influxdb3

[ ! -d influxdb3-explorer ] && mkdir -d influxdb3-explorer/config
[ ! -d influxdb3-explorer/db ] && mkdir -p influxdb3-explorer/db
[ ! -d influxdb3-explorer/ssl ] && mkdir -p influxdb3-explorer/ssl

# Setup influxdb3-explorer session key
touch .env
echo "SESSION_SECRET_KEY=$(openssl rand -hex 32)" >> .env

# Start docker and setup services
docker compose up -d

sleep 2 # Sleep for a bit to let the container initialize

echo "INFLUXDB_ADMIN_KEY=$(
  docker exec influxdb3-core influxdb3 create token --admin \
  | grep 'Token:' \
  | awk '{print $2}'
)" >> .env

TOKEN=$(grep 'INFLUXDB_ADMIN_KEY=' .env | cut -d'=' -f2)

docker exec influxdb3-core influxdb3 create database \
                                --retention-period 90d \
                                --token $TOKEN \
                                iot-lab

sleep 2 # Sleep for sanity

# Generate basic explorer config

cat > influxdb3-explorer/config/config.json <<EOF
{
  "DEFAULT_INFLUX_SERVER": "http://influxdb3-core:8181",
  "DEFAULT_INFLUX_DATABASE": "iot-lab",
  "DEFAULT_API_TOKEN": "$TOKEN",
  "DEFAULT_SERVER_NAME": "Dev InfluxDB 3"
}
EOF

docker compose restart influxdb3-explorer

echo "Services started"

docker ps