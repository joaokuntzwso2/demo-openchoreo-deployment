#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need docker; need k3d; need kubectl; need helm; need curl
VERSION="${OPENCHOREO_VERSION:-v1.2.2}"
ctx="$(demo_context)"

cluster_exists(){
  k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER"
}

if cluster_exists; then
  kubectl config get-contexts -o name 2>/dev/null | grep -Fxq "$ctx" \
    || die "k3d cluster '$CLUSTER' exists but Kubernetes context '$ctx' is missing. Use ./demo.sh reset to rebuild it safely."
  current="$(kubectl config current-context 2>/dev/null || true)"
  [[ "$current" == "$ctx" ]] || kubectl config use-context "$ctx" >/dev/null
  if kubectl get crd components.openchoreo.dev >/dev/null 2>&1; then
    log "OpenChoreo CRDs already installed in $ctx; leaving current installation in place"
    exit 0
  fi
  die "k3d cluster '$CLUSTER' already exists but OpenChoreo CRDs are absent. Refusing to install over a partial/unknown cluster. Run ./demo.sh reset."
fi

log "Installing OpenChoreo $VERSION on a fresh k3d cluster '$CLUSTER' with Workflow and Observability planes"
curl -fsSL "https://raw.githubusercontent.com/openchoreo/openchoreo/release-v1.2/install/k3d/k3d-install.sh" \
  | bash -s -- --version "$VERSION" --with-build --with-observability

cluster_exists || die "OpenChoreo installer returned successfully but k3d cluster '$CLUSTER' does not exist"
kubectl config get-contexts -o name 2>/dev/null | grep -Fxq "$ctx" \
  || die "OpenChoreo installer returned successfully but Kubernetes context '$ctx' does not exist"
kubectl config use-context "$ctx" >/dev/null
kubectl get crd components.openchoreo.dev >/dev/null 2>&1 \
  || die "OpenChoreo installer returned successfully but components.openchoreo.dev CRD is unavailable in $ctx"
log "OpenChoreo installation completed in $ctx"
