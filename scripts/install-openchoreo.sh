#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib.sh"

need docker
need k3d
need kubectl

VERSION="${OPENCHOREO_VERSION:-v1.2.2}"

QUICK_START_CLUSTER="openchoreo-quick-start"

QUICK_START_IMAGE="${OPENCHOREO_QUICK_START_IMAGE:-ghcr.io/openchoreo/quick-start:v1.2.2@sha256:b310704f2c47fc1e14072c3e5b63b1f7ab5ed64b8b7c2148c6957c0813e594db}"

INSTALLER_CONTAINER="${OPENCHOREO_INSTALLER_CONTAINER:-openchoreo-quick-start-installer}"

ctx="$(demo_context)"

cluster_exists() {
  k3d cluster list 2>/dev/null \
    | awk 'NR>1 {print $1}' \
    | grep -qx "$CLUSTER"
}

adopt_context() {
  if ! kubectl config get-contexts -o name 2>/dev/null \
      | grep -Fxq "$ctx"; then

    log "Merging kubeconfig for existing k3d cluster '$CLUSTER'"

    k3d kubeconfig merge "$CLUSTER" \
      --kubeconfig-merge-default \
      --kubeconfig-switch-context \
      >/dev/null
  else
    kubectl config use-context "$ctx" >/dev/null
  fi
}

if cluster_exists; then
  adopt_context

  if kubectl get crd components.openchoreo.dev >/dev/null 2>&1; then
    log "OpenChoreo CRDs already installed in $ctx; leaving current installation in place"
    exit 0
  fi

  die "k3d cluster '$CLUSTER' exists but OpenChoreo CRDs are absent. Refusing to install over a partial/unknown cluster. Run ./demo.sh reset."
fi

[[ "$VERSION" == "v1.2.2" ]] \
  || die "This showcase pins the tested OpenChoreo version to v1.2.2 (requested: $VERSION)"

[[ "$CLUSTER" == "$QUICK_START_CLUSTER" ]] \
  || die "Fresh GHCR Quick Start installations use cluster '$QUICK_START_CLUSTER'. Set OPENCHOREO_CLUSTER_NAME='$QUICK_START_CLUSTER' or remove the override."

log "Installing OpenChoreo $VERSION using the immutable GHCR Quick Start image"

docker pull "$QUICK_START_IMAGE" >/dev/null

docker rm -f "$INSTALLER_CONTAINER" >/dev/null 2>&1 || true

docker run --rm \
  --name "$INSTALLER_CONTAINER" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --network=host \
  -e "OPENCHOREO_INSTALL_VERSION=$VERSION" \
  --entrypoint /bin/bash \
  "$QUICK_START_IMAGE" \
  -lc '
set -Eeuo pipefail
cd /home/openchoreo

# The upstream Argo Workflows full-CRD hook downloads CRDs from
# raw.githubusercontent.com. For a deterministic showcase install, use
# the CRDs bundled with the Helm chart instead.
if ! grep -q "^[[:space:]]*argo-workflows:" .values-wp.yaml; then
  cat >> .values-wp.yaml <<'"'"'VALUES'"'"'

# Showcase reliability: avoid runtime raw.githubusercontent.com dependency.
argo-workflows:
  crds:
    full: false
VALUES
else
  if ! grep -A6 "^[[:space:]]*argo-workflows:" .values-wp.yaml \
      | grep -q "^[[:space:]]*full:[[:space:]]*false"; then
    echo "Unexpected argo-workflows configuration in Quick Start image:" >&2
    cat .values-wp.yaml >&2
    exit 1
  fi
fi

./install.sh \
  --version "$OPENCHOREO_INSTALL_VERSION" \
  --with-build \
  --with-observability
'

cluster_exists \
  || die "Quick Start installer completed but k3d cluster '$CLUSTER' does not exist"

adopt_context

kubectl get crd components.openchoreo.dev >/dev/null 2>&1 \
  || die "components.openchoreo.dev CRD is unavailable after installation"

kubectl get clusterdataplane default >/dev/null 2>&1 \
  || die "Default OpenChoreo Data Plane is unavailable"

kubectl get clusterworkflowplane default >/dev/null 2>&1 \
  || die "Default OpenChoreo Workflow Plane is unavailable"

kubectl get clusterobservabilityplane default >/dev/null 2>&1 \
  || die "Default OpenChoreo Observability Plane is unavailable"

log "OpenChoreo $VERSION installation completed successfully in $ctx"
