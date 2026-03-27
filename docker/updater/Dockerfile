FROM alpine:3.20

RUN apk add --no-cache docker-cli bash

WORKDIR /updater

COPY entrypoint.sh /updater/entrypoint.sh

RUN chmod +x /updater/entrypoint.sh

ENV UPDATE_INTERVAL_SECONDS=600
ENV DOCKER_COMPOSE_CMD="docker compose"
ENV COMPOSE_FILE="/opt/phyto/docker-compose.rpi.yml"
ENV COMPOSE_PROJECT_NAME="phytopi"

ENTRYPOINT ["/updater/entrypoint.sh"]

