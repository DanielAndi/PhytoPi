#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${UPDATE_INTERVAL_SECONDS:-600}"
COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-"docker compose"}
COMPOSE_FILE_PATH="${COMPOSE_FILE:-/opt/phyto/docker-compose.rpi.yml}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-phytopi}"

echo "[updater] Starting PhytoPi stack updater"
echo "[updater] Interval: ${INTERVAL}s"
echo "[updater] Compose file: ${COMPOSE_FILE_PATH}"
echo "[updater] Project: ${PROJECT_NAME}"

while true; do
  echo "[updater] Checking for new images..."
  if ${COMPOSE_CMD} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE_PATH}" pull; then
    echo "[updater] Pulled latest images, applying..."
    ${COMPOSE_CMD} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE_PATH}" up -d --remove-orphans
    echo "[updater] Stack updated."
  else
    echo "[updater] WARNING: docker compose pull failed; will retry later." >&2
  fi

  sleep "${INTERVAL}"
done

