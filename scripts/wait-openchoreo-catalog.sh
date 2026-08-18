#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

CTX="$(demo_context)"
CP_NS="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
BACKSTAGE="${OPENCHOREO_BACKSTAGE_DEPLOYMENT:-backstage}"
TIMEOUT="${OPENCHOREO_CATALOG_TIMEOUT:-360}"

log "Waiting for OpenChoreo catalog convergence"

start=$SECONDS
while (( SECONDS-start < TIMEOUT )); do
  if kubectl --context "$CTX" -n "$CP_NS" logs deployment/"$BACKSTAGE" --since=15m 2>/dev/null \
    | grep -Eq 'Successfully processed [0-9]+ entities \(2 domains, 11 systems, 19 components,'; then
    sleep "${OPENCHOREO_CATALOG_SETTLE_SECONDS:-20}"
    log "OpenChoreo catalog convergence: PASS"
    exit 0
  fi
  sleep 5
done

kubectl --context "$CTX" -n "$CP_NS" logs deployment/"$BACKSTAGE" --since=15m 2>/dev/null | tail -120 >&2 || true
die "Expected Backstage catalog state did not converge within ${TIMEOUT}s"
