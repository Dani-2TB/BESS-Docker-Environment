#!/bin/bash

rm -rf .influxdb3
rm -f .env

rm -f influxdb3-explorer/config/config.json

docker compose down
docker ps --all