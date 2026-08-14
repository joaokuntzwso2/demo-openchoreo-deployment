#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need docker; need curl; need python3; need kubectl
RANCHER_CONTAINER="${RANCHER_CONTAINER:-platform-rancher}"
RANCHER_IMAGE="${RANCHER_IMAGE:-rancher/rancher:latest}"
RANCHER_PASSWORD_FILE="${RANCHER_PASSWORD_FILE:-$ROOT/runtime/rancher-bootstrap-password}"

load_rancher_password() {
  if [[ -n "${RANCHER_BOOTSTRAP_PASSWORD:-}" ]]; then
    RANCHER_PASSWORD="$RANCHER_BOOTSTRAP_PASSWORD"
    return 0
  fi

  mkdir -p "$(dirname "$RANCHER_PASSWORD_FILE")"

  if [[ ! -s "$RANCHER_PASSWORD_FILE" ]]; then
    umask 077
    python3 - <<'PY_PASSWORD' >"$RANCHER_PASSWORD_FILE"
import secrets
print(secrets.token_urlsafe(24))
PY_PASSWORD
  fi

  RANCHER_PASSWORD="$(cat "$RANCHER_PASSWORD_FILE")"
}

load_rancher_password
RANCHER_URL="https://localhost:8444"
RANCHER_CLUSTER_URL="https://host.k3d.internal:8444"

start_rancher(){
  if docker ps --format '{{.Names}}' | grep -Fxq "$RANCHER_CONTAINER"; then
    log "Rancher is already running"
  elif docker ps -a --format '{{.Names}}' | grep -Fxq "$RANCHER_CONTAINER"; then
    docker start "$RANCHER_CONTAINER" >/dev/null
    log "Started existing Rancher container"
  else
    log "Starting Rancher for local platform demonstration"
    docker run -d --restart=unless-stopped --name "$RANCHER_CONTAINER" --privileged \
      -p 8444:443 \
      -e "CATTLE_BOOTSTRAP_PASSWORD=$RANCHER_PASSWORD" \
      -v platform-rancher-data:/var/lib/rancher \
      "$RANCHER_IMAGE" >/dev/null
  fi
  local start=$SECONDS
  while (( SECONDS-start < 300 )); do
    [[ "$(curl -ksS "$RANCHER_URL/ping" 2>/dev/null || true)" == "pong" ]] && return 0
    sleep 4
  done
  warn "Rancher did not become healthy within 300s. Core OpenChoreo demo remains usable."
  return 1
}

login(){
  curl -ksS -X POST "$RANCHER_URL/v3-public/localProviders/local?action=login" \
    -H 'content-type: application/json' \
    --data-binary "{\"username\":\"admin\",\"password\":\"$RANCHER_PASSWORD\",\"responseType\":\"json\"}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token", ""))' 2>/dev/null
}

register_cluster(){
  ensure_demo_context
  kubectl get ns cattle-system >/dev/null 2>&1 && { log "Rancher agents already exist in the OpenChoreo cluster"; return 0; }
  local token cluster_id reg_id command current
  token="$(login || true)"
  [[ -n "$token" ]] || { warn "Rancher API login is not ready; open $RANCHER_URL and register the cluster from Cluster Management if desired."; return 0; }

  # Make the address embedded in downstream agent manifests resolvable from k3d.
  curl -ksS -X PUT "$RANCHER_URL/v3/settings/server-url" -H "Authorization: Bearer $token" -H 'content-type: application/json' \
    --data-binary "{\"value\":\"$RANCHER_CLUSTER_URL\"}" >/dev/null 2>&1 || true

  current="$(curl -ksS "$RANCHER_URL/v3/clusters" -H "Authorization: Bearer $token" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x.get("id","") for x in d.get("data",[]) if x.get("name")=="openchoreo"),""))' 2>/dev/null || true)"
  if [[ -n "$current" ]]; then
    cluster_id="$current"
  else
    cluster_id="$(curl -ksS -X POST "$RANCHER_URL/v3/cluster" -H "Authorization: Bearer $token" -H 'content-type: application/json' \
      --data-binary '{"type":"cluster","name":"openchoreo","import":true}' | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id", ""))' 2>/dev/null || true)"
  fi
  [[ -n "$cluster_id" ]] || { warn "Could not create/find the Rancher registration object. Rancher itself is available at $RANCHER_URL."; return 0; }

  reg_id="$(curl -ksS -X POST "$RANCHER_URL/v3/clusters/$cluster_id/clusterregistrationtoken" -H "Authorization: Bearer $token" -H 'content-type: application/json' \
    --data-binary "{\"type\":\"clusterRegistrationToken\",\"clusterId\":\"$cluster_id\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id", ""))' 2>/dev/null || true)"
  [[ -n "$reg_id" ]] || { warn "Could not create a Rancher registration token. Use the Rancher UI to register the existing k3d cluster."; return 0; }

  local start=$SECONDS
  command=""
  while (( SECONDS-start < 90 )); do
    command="$(curl -ksS "$RANCHER_URL/v3/clusters/$cluster_id/clusterregistrationtoken/$reg_id" -H "Authorization: Bearer $token" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("insecureCommand", ""))' 2>/dev/null || true)"
    [[ -n "$command" ]] && break
    sleep 3
  done
  [[ -n "$command" ]] || { warn "Rancher did not generate a registration command yet; Rancher is running and can be registered from its UI."; return 0; }

  # The manifest itself contains host.k3d.internal. Only the host-side download URL
  # must use localhost because macOS does not resolve the k3d-only hostname.
  command="${command//$RANCHER_CLUSTER_URL/$RANCHER_URL}"
  log "Registering the existing OpenChoreo k3d cluster with Rancher"
  if eval "$command"; then
    log "Rancher registration manifest applied"
  else
    warn "Automatic Rancher registration failed. Rancher remains running at $RANCHER_URL; use Cluster Management > Import Existing to retry."
  fi
}

verify_registration(){
  ensure_demo_context
  local start=$SECONDS ready=0
  while (( SECONDS-start < 240 )); do
    if [[ "$(curl -ksS --max-time 5 "$RANCHER_URL/ping" 2>/dev/null || true)" == "pong" ]] \
      && kubectl get namespace cattle-system >/dev/null 2>&1; then
      available="$(kubectl get deployment cattle-cluster-agent -n cattle-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
      if [[ "${available:-0}" =~ ^[0-9]+$ ]] && (( available >= 1 )); then ready=1; break; fi
    fi
    sleep 5
  done
  if (( ready == 1 )); then
    log "Rancher is reachable and cattle-cluster-agent is Ready in the OpenChoreo cluster"
    return 0
  fi
  warn "Rancher registration is not Ready yet. Server ping=$(curl -ksS --max-time 5 "$RANCHER_URL/ping" 2>/dev/null || echo unavailable)"
  kubectl get pods -n cattle-system 2>/dev/null || true
  docker logs "$RANCHER_CONTAINER" --tail 80 2>/dev/null || true
  return 1
}

case "${1:-up}" in
  up) start_rancher; register_cluster ;;
  start) start_rancher ;;
  register) start_rancher; register_cluster ;;
  stop) docker stop "$RANCHER_CONTAINER" >/dev/null 2>&1 || true ;;
  destroy) docker rm -f "$RANCHER_CONTAINER" >/dev/null 2>&1 || true; docker volume rm platform-rancher-data >/dev/null 2>&1 || true ;;
  verify) verify_registration ;;
  status) docker ps -a --filter "name=^/${RANCHER_CONTAINER}$" --format 'Rancher: {{.Status}}'; printf 'URL: %s\nUser: admin\nPassword: %s\n' "$RANCHER_URL" "$RANCHER_PASSWORD" ;;
  *) echo "Usage: $0 [up|start|register|verify|stop|destroy|status]" >&2; exit 2 ;;
esac
