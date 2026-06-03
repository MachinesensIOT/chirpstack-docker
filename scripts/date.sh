#!/bin/bash
echo "Host Server Time "
date
echo "chirpstack-docker-chirpstack-rest-api-1 "
docker exec -it chirpstack-docker-chirpstack-rest-api-1 date
echo "chirpstack-docker-chirpstack-gateway-bridge-1 "
docker exec -it chirpstack-docker-chirpstack-gateway-bridge-1 date
echo "chirpstack-docker-chirpstack-gateway-bridge-basicstation-1 "
docker exec -it chirpstack-docker-chirpstack-gateway-bridge-basicstation-1 date
echo "chirpstack-docker-chirpstack-1 "
docker exec -it chirpstack-docker-chirpstack-1 date
echo "chirpstack-docker-telegraf-1 "
docker exec -it chirpstack-docker-telegraf-1 date
echo "chirpstack-docker-grafana-1 "
docker exec -it chirpstack-docker-grafana-1 date
echo "chirpstack-docker-postgres-1 "
docker exec -it chirpstack-docker-postgres-1 date
echo "chirpstack-docker-redis-1 "
docker exec -it chirpstack-docker-redis-1 date
echo "chirpstack-docker-mosquitto-1 "
docker exec -it chirpstack-docker-mosquitto-1 date
echo "chirpstack-docker-influxdb-1 "
docker exec -it chirpstack-docker-influxdb-1 date
