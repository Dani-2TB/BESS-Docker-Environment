#!/bin/bash

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must run as root."
    exit 1
fi

# --- Configuration ---
INFLUX_URL="http://localhost:8181"
DB_NAME="iot-lab"
RETENTION="90d"

# --- Directory Setup ---
mkdir -p .influxdb3/data .influxdb3/plugins
chown -R 1500:1500 .influxdb3

mkdir -p influxdb3-explorer/config
mkdir -p influxdb3-explorer/db
mkdir -p influxdb3-explorer/ssl

mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
# Aseguramos que existe la carpeta de dashboards
mkdir -p grafana/dashboards

# --- Environment Init ---
echo "# Auto-generated env file" > .env
SESSION_KEY=$(openssl rand -hex 32)
echo "SESSION_SECRET_KEY=$SESSION_KEY" >> .env

# --- Service Start: InfluxDB Core ---
echo "Starting InfluxDB Core..."
docker compose up -d influxdb3-core

# Function: wait_for_influx
# FIX: Aceptamos 401 como señal de que está vivo (pero protegido)
wait_for_influx() {
    echo "Waiting for InfluxDB to be ready..."
    while true; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$INFLUX_URL/health")
        if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "401" ]]; then
            echo "InfluxDB is up (Status: $HTTP_CODE)."
            break
        fi
        sleep 1
    done
}

wait_for_influx

# --- Token & Database Provisioning ---
echo "Generating Admin Token..."
ADMIN_TOKEN=$(docker exec influxdb3-core influxdb3 create token --admin | grep 'Token:' | awk '{print $2}')

if [ -z "$ADMIN_TOKEN" ]; then
    echo "Error: Failed to retrieve Admin Token."
    exit 1
fi

echo "INFLUXDB_ADMIN_KEY=$ADMIN_TOKEN" >> .env

echo "Creating database: $DB_NAME..."
docker exec influxdb3-core influxdb3 create database \
    --retention-period $RETENTION \
    --token "$ADMIN_TOKEN" \
    $DB_NAME

# --- Configuration Generation ---

# 1. InfluxDB Explorer Config
cat > influxdb3-explorer/config/config.json <<EOF
{
  "DEFAULT_INFLUX_SERVER": "http://influxdb3-core:8181",
  "DEFAULT_INFLUX_DATABASE": "$DB_NAME",
  "DEFAULT_API_TOKEN": "$ADMIN_TOKEN",
  "DEFAULT_SERVER_NAME": "Dev InfluxDB 3"
}
EOF

# 2. Grafana Datasource (MODO INFLUXQL)
# Usamos customHeaders para pasar el token, ya que el modo InfluxQL nativo usa user/pass
cat > grafana/provisioning/datasources/datasources.yaml <<EOF
apiVersion: 1

datasources:
  - name: InfluxDB_BESS
    type: influxdb
    uid: bess-influx-01
    access: proxy
    url: http://influxdb3-core:8181
    database: $DB_NAME
    isDefault: true
    jsonData:
      httpMode: GET
      httpHeaderName1: "Authorization"
    secureJsonData:
      httpHeaderValue1: "Token $ADMIN_TOKEN"
EOF

# 3. Grafana Dashboard Provisioning
cat > grafana/provisioning/dashboards/dashboards.yaml <<EOF
apiVersion: 1

providers:
  - name: 'BESS Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF

# --- Final Startup ---
echo "Starting remaining services..."
docker compose up -d

echo "Setup Complete."
docker ps