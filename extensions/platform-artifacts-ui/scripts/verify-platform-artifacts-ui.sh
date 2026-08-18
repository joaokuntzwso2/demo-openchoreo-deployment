#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=platform-artifacts-lib.sh
source "$ROOT/scripts/platform-artifacts-lib.sh"

CLUSTER="${OPENCHOREO_CLUSTER_NAME:-openchoreo-quick-start}"
NAMESPACE="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
DEMO_NS="${PLATFORM_ARTIFACTS_NAMESPACE:-platform-demo}"
DEPLOYMENT="${OPENCHOREO_BACKSTAGE_DEPLOYMENT:-backstage}"
ARCH="$(pa_target_arch)"
IMAGE="$(pa_default_image "$ARCH")"
LABEL_JSONPATH='{.metadata.labels.demo\.openchoreo\.dev/custom-artifact}'

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is required" >&2; exit 1; }; }
need kubectl
need k3d
need docker

k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context >/dev/null
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=5m >/dev/null

ACTUAL_IMAGE="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')"
if [[ "$ACTUAL_IMAGE" != "$IMAGE" ]]; then
  echo "FAIL: Backstage image is '$ACTUAL_IMAGE', expected '$IMAGE'" >&2
  exit 1
fi

LOCAL_ARCH="$(pa_normalize_arch "$(pa_image_arch "$IMAGE" 2>/dev/null || true)" 2>/dev/null || true)"
if [[ "$LOCAL_ARCH" != "$ARCH" ]]; then
  echo "FAIL: local custom portal image architecture '$LOCAL_ARCH' does not match cluster architecture '$ARCH'" >&2
  exit 1
fi

PULL_POLICY="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')"
[[ "$PULL_POLICY" == "Never" ]] || { echo "FAIL: custom local portal image must use imagePullPolicy=Never, got '$PULL_POLICY'" >&2; exit 1; }

checks=(
  "clusterprojecttypes.openchoreo.dev|regulated-platform|"
  "clustercomponenttypes.openchoreo.dev|regulated-service|"
  "clustertraits.openchoreo.dev|bank-runtime-hardening|"
  "clusterresourcetypes.openchoreo.dev|platform-valkey-cache|"
  "clusterworkflows.openchoreo.dev|regulated-release-gate|"
  "workflows.openchoreo.dev|platform-policy-gate|$DEMO_NS"
  "deploymentpipelines.openchoreo.dev|platform-standard|$DEMO_NS"
  "resources.openchoreo.dev|payment-idempotency-cache|$DEMO_NS"
  "environments.openchoreo.dev|development|$DEMO_NS"
  "environments.openchoreo.dev|staging|$DEMO_NS"
  "environments.openchoreo.dev|production|$DEMO_NS"
  "observabilityalertsnotificationchannels.openchoreo.dev|platform-webhook-development|$DEMO_NS"
  "observabilityalertsnotificationchannels.openchoreo.dev|platform-webhook-staging|$DEMO_NS"
  "observabilityalertsnotificationchannels.openchoreo.dev|platform-webhook-production|$DEMO_NS"
  "authzroles.openchoreo.dev|platform-auditor|$DEMO_NS"
  "clusterauthzrolebindings.openchoreo.dev|platform-demo-developers|"
  "authzrolebindings.openchoreo.dev|platform-demo-auditors|$DEMO_NS"
)

count=0
for check in "${checks[@]}"; do
  IFS='|' read -r resource name ns <<<"$check"
  if [[ -n "$ns" ]]; then
    if ! kubectl get "$resource" "$name" -n "$ns" >/dev/null 2>&1; then
      echo "FAIL: expected Platform Artifact $resource/$name does not exist" >&2
      exit 1
    fi
    value="$(kubectl get "$resource" "$name" -n "$ns" -o jsonpath="$LABEL_JSONPATH")"
  else
    if ! kubectl get "$resource" "$name" >/dev/null 2>&1; then
      echo "FAIL: expected Platform Artifact $resource/$name does not exist" >&2
      exit 1
    fi
    value="$(kubectl get "$resource" "$name" -o jsonpath="$LABEL_JSONPATH")"
  fi
  if [[ "$value" != "true" ]]; then
    echo "FAIL: $resource/$name is not marked as a custom artifact" >&2
    echo "      Repair with: $ROOT/scripts/repair-platform-artifacts-metadata.sh" >&2
    exit 1
  fi
  count=$((count+1))
done

# The SPA route should resolve even though API data calls require the logged-in browser token.
if command -v curl >/dev/null 2>&1; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 http://openchoreo.localhost:8080/platform-artifacts || true)"
  if [[ "$code" != "200" && "$code" != "302" && "$code" != "303" && "$code" != "307" ]]; then
    echo "WARN: portal route returned HTTP $code; check local gateway/hosts if the browser route is unavailable" >&2
  fi
fi

echo "PASS: Platform Artifacts UI is active for $ARCH and $count demo-owned OpenChoreo artifacts carry live ownership metadata."
