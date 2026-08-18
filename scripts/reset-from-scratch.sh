#!/usr/bin/env bash
# Destructive clean-room proof limited to this repository's k3d cluster, Rancher
# management k3d cluster, runtime state, webhook process and platform-demo/* images.
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need docker; need k3d; need kubectl
ENABLE_AI="${ENABLE_AI:-0}"
if [[ "$ENABLE_AI" == "1" && -z "${OPENAI_API_KEY:-}" ]]; then die "ENABLE_AI=1 requires OPENAI_API_KEY before a destructive reset."; fi
"$ROOT/scripts/preflight.sh"
log "Stopping local auxiliary processes"
"$ROOT/scripts/stop-webhook-receiver.sh" || true
"$ROOT/scripts/rancher.sh" destroy || true
log "Deleting only k3d cluster '$CLUSTER'"
if k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER"; then k3d cluster delete "$CLUSTER"; else echo "  cluster does not exist"; fi
docker rm -f "k3d-${CLUSTER}-tools" >/dev/null 2>&1 || true
log "Removing only local platform-demo/* application image tags"
docker image ls --filter 'reference=platform-demo/*' --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | sort -u | while IFS= read -r tag; do [[ -n "$tag" ]] || continue; docker image rm -f "$tag" >/dev/null 2>&1 || true; echo "  removed $tag"; done
log "Clearing deterministic runtime artifacts"
rm -rf "$ROOT/runtime"; mkdir -p "$ROOT/runtime"
rm -f /tmp/platform-financial-*.json /tmp/platform-*.json 2>/dev/null || true
log "Starting fresh clone-equivalent bootstrap with no-cache application image builds"
PLATFORM_DEMO_NO_CACHE=1 "$ROOT/scripts/bootstrap-all.sh"
if [[ "$ENABLE_AI" == "1" ]]; then log "Enabling built-in SRE, FinOps and Portal Assistant"; "$ROOT/scripts/enable-ai-agents.sh"; fi
log "Running strict clean-room verification"
"$ROOT/scripts/verify-clean-room.sh"
if [[ "$ENABLE_AI" == "1" ]]; then
  kubectl rollout status deployment/sre-agent -n openchoreo-observability-plane --timeout=300s
  kubectl rollout status deployment/finops-agent -n openchoreo-observability-plane --timeout=300s
  kubectl rollout status deployment/portal-assistant -n openchoreo-control-plane --timeout=300s
fi
log "FULL CLEAN-ROOM RUN PASSED"
