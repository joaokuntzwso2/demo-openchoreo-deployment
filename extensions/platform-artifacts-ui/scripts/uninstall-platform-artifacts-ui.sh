#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${OPENCHOREO_CLUSTER_NAME:-openchoreo-quick-start}"
NAMESPACE="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
DEPLOYMENT="${OPENCHOREO_BACKSTAGE_DEPLOYMENT:-backstage}"

k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context >/dev/null

STOCK="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.demo\.openchoreo\.dev/platform-artifacts-stock-image}' 2>/dev/null || true)"
STOCK_PULL_POLICY="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.demo\.openchoreo\.dev/platform-artifacts-stock-pull-policy}' 2>/dev/null || true)"
[[ -n "$STOCK_PULL_POLICY" ]] || STOCK_PULL_POLICY="IfNotPresent"
if [[ -z "$STOCK" ]]; then
  echo "ERROR: original Backstage image annotation is missing; refusing to guess a stock image." >&2
  echo "Reapply the OpenChoreo control-plane Helm release or set the image explicitly." >&2
  exit 1
fi

CONTAINER="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].name}')"
kubectl set image deployment/"$DEPLOYMENT" -n "$NAMESPACE" "$CONTAINER=$STOCK" >/dev/null
kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" --type='strategic' \
  -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$CONTAINER\",\"imagePullPolicy\":\"$STOCK_PULL_POLICY\"}]}}}}" >/dev/null
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=5m

echo "Restored OpenChoreo Backstage image: $STOCK"
echo "Custom metadata labels/annotations were intentionally left in place; they are harmless platform metadata."
