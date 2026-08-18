#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

RANCHER_CLUSTER="${RANCHER_CLUSTER:-rancher-mgmt}"
RANCHER_CONTEXT="${RANCHER_CONTEXT:-k3d-${RANCHER_CLUSTER}}"
RANCHER_K3S_IMAGE="${RANCHER_K3S_IMAGE:-rancher/k3s:v1.35.5-k3s1}"
RANCHER_CHART_VERSION="${RANCHER_CHART_VERSION:-2.14.3}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.21.1}"
RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-rancher.localhost}"
RANCHER_HTTPS_PORT="${RANCHER_HTTPS_PORT:-8444}"
RANCHER_API_PORT="${RANCHER_API_PORT:-6551}"
RANCHER_URL="https://${RANCHER_HOSTNAME}:${RANCHER_HTTPS_PORT}"
RANCHER_PASSWORD_FILE="${RANCHER_PASSWORD_FILE:-$ROOT/runtime/rancher-bootstrap-password}"

exists() {
  k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$RANCHER_CLUSTER"
}

restore_context() {
  ctx="$(demo_context)"
  kubectl config get-contexts -o name 2>/dev/null | grep -Fxq "$ctx" || return 0
  kubectl config use-context "$ctx" >/dev/null 2>&1 || true
}

password() {
  mkdir -p "$(dirname "$RANCHER_PASSWORD_FILE")"
  if [[ -n "${RANCHER_BOOTSTRAP_PASSWORD:-}" ]]; then
    RANCHER_PASSWORD="$RANCHER_BOOTSTRAP_PASSWORD"
  else
    if [[ ! -s "$RANCHER_PASSWORD_FILE" ]]; then
      umask 077
      python3 -c 'import secrets; print(secrets.token_urlsafe(24))' > "$RANCHER_PASSWORD_FILE"
    fi
    RANCHER_PASSWORD="$(cat "$RANCHER_PASSWORD_FILE")"
  fi
}

create_cluster() {
  exists && return 0
  "$ROOT/scripts/prepare-host.sh"
  log "Creating Rancher management k3d cluster"
  k3d cluster create "$RANCHER_CLUSTER" \
    --image "$RANCHER_K3S_IMAGE" \
    --servers 1 \
    --agents 0 \
    --api-port "$RANCHER_API_PORT" \
    -p "${RANCHER_HTTPS_PORT}:443@loadbalancer" \
    --wait \
    --timeout 180s
  k3d kubeconfig merge "$RANCHER_CLUSTER" --kubeconfig-merge-default --update >/dev/null
  kubectl --context "$RANCHER_CONTEXT" wait node --all --for=condition=Ready --timeout=180s
}

install_cert_manager() {
  helm repo add jetstack https://charts.jetstack.io --force-update >/dev/null
  helm repo update >/dev/null
  log "Installing cert-manager $CERT_MANAGER_VERSION"
  helm upgrade --install cert-manager jetstack/cert-manager \
    --kube-context "$RANCHER_CONTEXT" \
    --namespace cert-manager \
    --create-namespace \
    --version "$CERT_MANAGER_VERSION" \
    --set crds.enabled=true \
    --wait \
    --timeout 10m
}

install_rancher() {
  password
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest --force-update >/dev/null
  helm repo update >/dev/null
  helm show chart rancher-latest/rancher --version "$RANCHER_CHART_VERSION" >/dev/null \
    || die "Rancher chart $RANCHER_CHART_VERSION is unavailable"
  log "Installing Rancher $RANCHER_CHART_VERSION"
  helm upgrade --install rancher rancher-latest/rancher \
    --kube-context "$RANCHER_CONTEXT" \
    --namespace cattle-system \
    --create-namespace \
    --version "$RANCHER_CHART_VERSION" \
    --set hostname="$RANCHER_HOSTNAME" \
    --set replicas=1 \
    --set bootstrapPassword="$RANCHER_PASSWORD" \
    --wait \
    --timeout 15m
}

verify() {
  exists || die "Rancher cluster does not exist"

  kubectl --context "$RANCHER_CONTEXT"     wait node --all     --for=condition=Ready     --timeout=180s >/dev/null
  kubectl --context "$RANCHER_CONTEXT" -n cattle-system rollout status deployment/rancher --timeout=300s
  start=$SECONDS
  while (( SECONDS-start < 300 )); do
    [[ "$(curl -ksS --max-time 5 "$RANCHER_URL/readyz" 2>/dev/null || true)" == "ok" ]] && break
    sleep 5
  done
  [[ "$(curl -ksS --max-time 5 "$RANCHER_URL/readyz" 2>/dev/null || true)" == "ok" ]] || die "Rancher /readyz failed"
  kubectl --context "$RANCHER_CONTEXT"     get apiservice v1.ext.cattle.io >/dev/null 2>&1     || die "Rancher APIService v1.ext.cattle.io does not exist"

  available="$(
    kubectl --context "$RANCHER_CONTEXT"       get apiservice v1.ext.cattle.io       -o jsonpath='{range .status.conditions[?(@.type=="Available")]}{.status}{end}'
  )"

  [[ "$available" == "True" ]]     || die "Rancher APIService v1.ext.cattle.io is not Available=True"

  imperative_endpoints="$(
    kubectl --context "$RANCHER_CONTEXT"       -n cattle-system       get endpoints imperative-api-extension       -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}'       2>/dev/null || true
  )"

  [[ -n "$imperative_endpoints" ]]     || die "Rancher imperative-api-extension has no ready endpoints"

  log "Rancher management UI: PASS"
  printf '  %s\n' "$RANCHER_URL"
}

up() {
  create_cluster
  install_cert_manager
  install_rancher
  verify
  restore_context
}

case "${1:-up}" in
  up) up ;;
  start)
    if exists; then k3d cluster start "$RANCHER_CLUSTER" >/dev/null; verify; restore_context; else up; fi
    ;;
  stop)
    exists && k3d cluster stop "$RANCHER_CLUSTER" >/dev/null || true
    restore_context
    ;;
  destroy)
    exists && k3d cluster delete "$RANCHER_CLUSTER" >/dev/null || true
    restore_context
    ;;
  verify)
    verify
    restore_context
    ;;
  status)
    if exists; then
      k3d cluster list | awk -v c="$RANCHER_CLUSTER" 'NR==1 || $1==c'
      printf 'URL: %s\n' "$RANCHER_URL"
    else
      echo "Rancher: disabled/not installed (optional)"
    fi
    ;;
  register)
    warn "OpenChoreo downstream import is not yet part of strict fresh-clone acceptance for the new Helm-based Rancher architecture."
    restore_context
    ;;
  *)
    echo "Usage: $0 [up|start|stop|destroy|verify|status|register]" >&2
    exit 2
    ;;
esac
