#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
ensure_demo_context
kubectl apply -f "$ROOT/platform/08-k8s-ops-rbac.yaml" >/dev/null
start=$SECONDS; OPS_NS=""
while (( SECONDS-start < 180 )); do
  OPS_NS="$(kubectl get ns -l 'openchoreo.dev/project=platform-ops,openchoreo.dev/environment=development' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "$OPS_NS" ]] && break
  sleep 2
done
[[ -n "$OPS_NS" ]] || die "Could not resolve the platform-ops development cell namespace"
cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-demo-k8s-ops
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-demo-k8s-ops
subjects:
  - kind: Group
    apiGroup: rbac.authorization.k8s.io
    name: system:serviceaccounts:$OPS_NS
YAML
log "Kubernetes Operations Console RBAC bound to ServiceAccounts in $OPS_NS"
