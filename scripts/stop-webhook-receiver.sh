#!/usr/bin/env bash
set -euo pipefail
container="platform-webhook-receiver"
docker rm -f "$container" >/dev/null 2>&1 || true
