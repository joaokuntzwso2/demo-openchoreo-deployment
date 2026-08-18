#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
log "OpenChoreo planes"
kubectl get pods -A | grep -E 'openchoreo|workflow|observability|backstage|gateway|argo' || true
log "Platform application desired state"
kubectl get project,component,resource,releasebinding,resourcereleasebinding,projectreleasebinding -n "$NS" 2>/dev/null || true
log "Development Kubernetes workloads"
kubectl get deploy,statefulset,pod,svc,httproute -A 2>/dev/null | grep -E 'dp-platform-demo-|platform-portal|financial|telco|payment|customer|risk|compliance|k8s-ops' || true
log "External routes"
for c in platform-portal financial-bff financial-agent telco-portal telco-mcp k8s-ops-console telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade; do printf '%-28s %s\n' "$c:" "$(external_url "$c" || echo 'route pending')"; done
printf '%-28s %s\n' 'OpenChoreo:' 'http://openchoreo.localhost:8080'
printf '%-28s %s\n' 'Platform Artifacts:' 'http://openchoreo.localhost:8080/platform-artifacts'
if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then
  if "$ROOT/scripts/rancher.sh" health >/dev/null 2>&1; then
    printf '%-28s %s\n' 'Rancher:' 'https://rancher.localhost:8444/dashboard/'
  else
    printf '%-28s %s\n' 'Rancher:' 'enabled but NOT READY'
  fi
else
  printf '%-28s %s\n' 'Rancher:' 'disabled (optional)'
fi
