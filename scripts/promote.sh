#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl
ensure_demo_context
env="${1:-staging}"
scope="${2:-financial}"
[[ "$env" == staging || "$env" == production ]] || die "Usage: $0 staging|production [financial|telco|all]"
case "$scope" in
  financial) components=(accounts-service customer-mcp fraud-service risk-mcp compliance-service compliance-mcp payments-service financial-bff financial-agent) ;;
  telco) components=(telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal) ;;
  all) components=(accounts-service customer-mcp fraud-service risk-mcp compliance-service compliance-mcp payments-service financial-bff financial-agent telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal k8s-ops-console platform-portal) ;;
  *) die "Unknown scope '$scope'. Use financial, telco or all." ;;
esac

if [[ "$scope" == financial || "$scope" == all ]]; then
  log "Pinning payment-idempotency-cache into $env before financial dependents"
  pin_resource payment-idempotency-cache "$env"
fi

log "Promoting $scope application slice to $env using existing immutable ComponentReleases"
for c in "${components[@]}"; do
  latest="$(kubectl get component "$c" -n "$NS" -o jsonpath='{.status.latestRelease.name}')"
  [[ -n "$latest" ]] || die "No latest ComponentRelease for $c"
  rb="${c}-${env}"
  project="$(kubectl get component "$c" -n "$NS" -o jsonpath='{.spec.owner.projectName}')"
  if kubectl get releasebinding "$rb" -n "$NS" >/dev/null 2>&1; then
    kubectl patch releasebinding "$rb" -n "$NS" --type=merge -p "{\"spec\":{\"componentRelease\":\"$latest\"}}" >/dev/null
  else
    cat <<YAML | kubectl apply -f -
apiVersion: openchoreo.dev/v1alpha1
kind: ReleaseBinding
metadata:
  name: $rb
  namespace: $NS
spec:
  owner:
    projectName: $project
    componentName: $c
  environment: $env
  componentRelease: $latest
YAML
  fi
  wait_ready releasebinding "$rb" "$NS" 360
  printf '  %-30s %s\n' "$c" "$latest"
done
log "Promotion to $env completed for scope '$scope'"
