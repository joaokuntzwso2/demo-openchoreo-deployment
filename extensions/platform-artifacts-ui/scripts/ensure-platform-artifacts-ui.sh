#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=platform-artifacts-lib.sh
source "$ROOT/scripts/platform-artifacts-lib.sh"

CLUSTER="${OPENCHOREO_CLUSTER_NAME:-openchoreo-quick-start}"
NAMESPACE="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
DEPLOYMENT="${OPENCHOREO_BACKSTAGE_DEPLOYMENT:-backstage}"
ROLLOUT_TIMEOUT="${PLATFORM_ARTIFACTS_ROLLOUT_TIMEOUT:-10m}"
FORCE_BUILD=0

for arg in "$@"; do
  case "$arg" in
    --force-build) FORCE_BUILD=1 ;;
    --reuse-image) : ;; # backwards-compatible no-op: reuse is already the default when valid
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is required" >&2; exit 1; }; }
need kubectl
need docker
need k3d
need git
need python3

if ! pa_cluster_exists "$CLUSTER"; then
  echo "ERROR: k3d cluster '$CLUSTER' does not exist. OpenChoreo must be installed before the portal extension is applied." >&2
  exit 1
fi

k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context >/dev/null
ARCH="$(pa_target_arch)"
IMAGE="$(pa_default_image "$ARCH")"

# Reconcile ownership metadata before any potentially expensive portal build.
# This makes the UI data contract independent from build/rollout timing.
"$ROOT/scripts/label-demo-artifacts.sh"

if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
  DEPLOYMENT="$(kubectl get deployment -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}' \
    | awk 'tolower($0) ~ /backstage|openchoreo-ui/ {print $1; exit}')"
fi
[[ -n "$DEPLOYMENT" ]] && kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1 \
  || { echo "ERROR: could not find the OpenChoreo Backstage deployment in $NAMESPACE" >&2; exit 1; }

BUILT=0
if [[ "$FORCE_BUILD" == "1" ]] || ! docker image inspect "$IMAGE" >/dev/null 2>&1 || ! pa_image_matches_arch "$IMAGE" "$ARCH"; then
  if docker image inspect "$IMAGE" >/dev/null 2>&1 && ! pa_image_matches_arch "$IMAGE" "$ARCH"; then
    echo "==> Existing $IMAGE has the wrong architecture; rebuilding for $ARCH"
  else
    echo "==> Architecture-native portal image is not ready; building for $ARCH"
  fi
  PLATFORM_ARTIFACTS_ARCH="$ARCH" PLATFORM_ARTIFACTS_IMAGE="$IMAGE" \
    "$ROOT/scripts/build-platform-artifacts-ui.sh"
  BUILT=1
else
  echo "==> Reusing architecture-compatible custom portal image: $IMAGE ($ARCH)"
fi

LOCAL_ARCH="$(pa_normalize_arch "$(pa_image_arch "$IMAGE")")"
[[ "$LOCAL_ARCH" == "$ARCH" ]] || { echo "ERROR: local image architecture $LOCAL_ARCH does not match cluster architecture $ARCH" >&2; exit 1; }

echo "==> Importing $IMAGE into k3d cluster '$CLUSTER'"
if ! k3d image import "$IMAGE" -c "$CLUSTER"; then
  echo "WARN: k3d image import failed; trying direct containerd import" >&2
  SERVER_NODE="k3d-${CLUSTER}-server-0"
  docker inspect "$SERVER_NODE" >/dev/null 2>&1 || { echo "ERROR: missing k3d server node $SERVER_NODE" >&2; exit 1; }
  docker save "$IMAGE" | docker exec -i "$SERVER_NODE" ctr -n k8s.io images import -
fi

CONTAINER="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].name}')"
CURRENT_IMAGE="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')"
CURRENT_PULL_POLICY="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')"
STOCK_IMAGE="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.demo\.openchoreo\.dev/platform-artifacts-stock-image}' 2>/dev/null || true)"

if [[ -z "$STOCK_IMAGE" && "$CURRENT_IMAGE" != openchoreo-ui-platform-artifacts:* ]]; then
  kubectl annotate deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    demo.openchoreo.dev/platform-artifacts-stock-image="$CURRENT_IMAGE" \
    demo.openchoreo.dev/platform-artifacts-stock-pull-policy="$CURRENT_PULL_POLICY" \
    --overwrite >/dev/null
fi

# The image is deliberately local to the k3d node. Never ask a registry for it.
kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" --type='strategic' \
  -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$CONTAINER\",\"imagePullPolicy\":\"Never\"}]}}}}" >/dev/null

NEEDS_ROLLOUT=0
if [[ "$CURRENT_IMAGE" != "$IMAGE" ]]; then
  kubectl set image deployment/"$DEPLOYMENT" -n "$NAMESPACE" "$CONTAINER=$IMAGE" >/dev/null
  NEEDS_ROLLOUT=1
elif [[ "$BUILT" == "1" ]]; then
  NEEDS_ROLLOUT=1
fi

if [[ "$NEEDS_ROLLOUT" == "1" ]]; then
  # Force a rollout when a same-tag local image was rebuilt.
  kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE" >/dev/null
fi

portal_diagnostics() {
  echo >&2
  echo "==> Platform Artifacts UI rollout diagnostics" >&2
  echo "    Cluster architecture: $ARCH" >&2
  echo "    Local image:          $IMAGE ($(pa_image_arch "$IMAGE" 2>/dev/null || echo unknown))" >&2
  kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o wide >&2 || true
  kubectl get rs -n "$NAMESPACE" | grep -E '^backstage-|NAME' >&2 || true
  kubectl get pods -n "$NAMESPACE" -o wide | grep -E 'backstage|NAME' >&2 || true

  while IFS= read -r pod; do
    [[ -n "$pod" ]] || continue
    pod_image="$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)"
    [[ "$pod_image" == "$IMAGE" ]] || continue
    echo >&2
    echo "--- describe $pod ---" >&2
    kubectl describe pod "$pod" -n "$NAMESPACE" >&2 || true
    echo >&2
    echo "--- logs $pod ---" >&2
    kubectl logs "$pod" -n "$NAMESPACE" --tail=200 >&2 || true
    kubectl logs "$pod" -n "$NAMESPACE" --previous --tail=200 >&2 2>/dev/null || true
  done < <(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | sed 's#^pod/##' | grep '^backstage-' || true)
}

if ! kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"; then
  portal_diagnostics
  echo "ERROR: custom OpenChoreo portal did not become Ready within $ROLLOUT_TIMEOUT" >&2
  exit 1
fi

ACTUAL_IMAGE="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')"
[[ "$ACTUAL_IMAGE" == "$IMAGE" ]] || { echo "ERROR: Backstage deployment is using '$ACTUAL_IMAGE', expected '$IMAGE'" >&2; exit 1; }

"$ROOT/scripts/label-demo-artifacts.sh"
PLATFORM_ARTIFACTS_ARCH="$ARCH" PLATFORM_ARTIFACTS_IMAGE="$IMAGE" \
  "$ROOT/scripts/verify-platform-artifacts-ui.sh"

echo "==> Platform Artifacts UI ready"
echo "    Page:         http://openchoreo.localhost:8080/platform-artifacts"
echo "    Architecture: $ARCH"
echo "    Image:        $IMAGE"
echo "    Deployment:   $NAMESPACE/$DEPLOYMENT"
