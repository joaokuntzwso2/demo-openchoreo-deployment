#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need docker; need k3d; need kubectl
ensure_demo_context

services=(accounts-service payments-service fraud-service compliance-service financial-bff mcp-customer mcp-risk mcp-compliance financial-agent platform-portal telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal k8s-ops-console)
server_node="k3d-${CLUSTER}-server-0"
docker inspect "$server_node" >/dev/null 2>&1 || die "Cannot find k3d server node $server_node"

image_present(){
  local svc="$1" expected images
  expected="docker.io/platform-demo/${svc}:1.0.0"

  # Avoid ctr|grep -q under pipefail: grep may exit early after a match,
  # ctr receives SIGPIPE, and the pipeline becomes a false negative.
  images="$(docker exec "$server_node" ctr -n k8s.io images ls -q 2>/dev/null)" || return 1
  grep -Fx "$expected" <<<"$images" >/dev/null
}

missing=()
for svc in "${services[@]}"; do image_present "$svc" || missing+=("$svc"); done

if ((${#missing[@]})); then
  warn "${#missing[@]} application image(s) are missing from k3d containerd: ${missing[*]}"
  "$ROOT/scripts/build-images.sh"
else
  log "All 19 platform application images are already present in k3d containerd"
fi

missing=()
for svc in "${services[@]}"; do image_present "$svc" || missing+=("$svc"); done
((${#missing[@]} == 0)) || die "Application images still missing after deterministic import: ${missing[*]}"

log "19 platform application images verified in $server_node"
docker exec "$server_node" ctr -n k8s.io images ls -q 2>/dev/null | grep 'platform-demo/' | sort

log "Deleting only platform application pods blocked on image pull, if any"
kubectl get pods -A --no-headers 2>/dev/null \
  | awk '$1 ~ /^dp-platform-demo-.*-development-/ && ($4=="ImagePullBackOff" || $4=="ErrImagePull") {print $1, $2}' \
  | while read -r ns pod; do
      [[ -n "${ns:-}" && -n "${pod:-}" ]] || continue
      echo "  deleting $ns/$pod"
      kubectl delete pod -n "$ns" "$pod" --wait=false >/dev/null || true
    done
