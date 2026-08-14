#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need docker; need curl
mkdir -p "$ROOT/runtime"
container="platform-webhook-receiver"
image="platform-demo/platform-webhook-receiver:1.0.0"

if docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
  curl -fsS http://localhost:18081/health | grep -q '"status":"UP"' \
    || die "Webhook receiver container is running but its health endpoint failed"
  log "Containerized webhook receiver already running"
  exit 0
fi

docker rm -f "$container" >/dev/null 2>&1 || true
if ! docker image inspect "$image" >/dev/null 2>&1; then
  log "Building the containerized alert/webhook receiver"
  BUILDX_NO_DEFAULT_ATTESTATIONS=1 docker buildx build --load --provenance=false \
    -f "$ROOT/services/platform-webhook-receiver/Dockerfile" \
    -t "$image" "$ROOT" >/dev/null
fi

# Refuse to silently bind around an unrelated process/container.
if python3 - <<'PY'
import socket
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
try: s.bind(('127.0.0.1',18081))
except OSError: raise SystemExit(1)
finally: s.close()
PY
then :; else
  die "Host port 18081 is already in use by another process"
fi

: > "$ROOT/runtime/alerts.ndjson"
docker run -d --name "$container" --restart=unless-stopped \
  -p 18081:18081 \
  -e ALERT_LOG=/data/alerts.ndjson \
  -v "$ROOT/runtime:/data" \
  "$image" >/dev/null

for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if curl -fsS http://localhost:18081/health 2>/dev/null | grep -q '"status":"UP"'; then
    log "Containerized webhook receiver ready on host port 18081"
    exit 0
  fi
  sleep 1
done
docker logs "$container" >&2 || true
die "Webhook receiver did not become healthy on port 18081"
