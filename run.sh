#!/bin/bash

COMPOSE_PROJECT="video-dl-$(date +%s)-$$"

cleanup() {
    echo "Cleaning up compose project: $COMPOSE_PROJECT"
    docker compose -p "$COMPOSE_PROJECT" down -v --remove-orphans
    docker compose -p "$COMPOSE_PROJECT" rm -f
    exit 0
}

trap cleanup SIGINT SIGTERM

docker compose -p "$COMPOSE_PROJECT" run --rm video-downloader /app/src/main.sh "$@"
cleanup
