#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl delete namespace platform-demo --ignore-not-found
kubectl delete clusterprojecttype regulated-platform --ignore-not-found
kubectl delete clusterresourcetype platform-valkey-cache --ignore-not-found
"$ROOT/scripts/stop-webhook-receiver.sh" || true
printf 'Platform application objects removed. OpenChoreo itself was intentionally left installed.\n'
