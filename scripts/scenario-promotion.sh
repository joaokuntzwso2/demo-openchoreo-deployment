#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl
ensure_demo_context

release="$(kubectl get component payments-service -n "$NS" -o jsonpath='{.status.latestRelease.name}')"
[[ -n "$release" ]] || die "payments-service has no latest ComponentRelease"

show_bindings(){
  echo
  printf '%-16s %-55s\n' ENVIRONMENT COMPONENT_RELEASE
  printf '%-16s %-55s\n' development "$(kubectl get releasebinding payments-service-development -n "$NS" -o jsonpath='{.spec.componentRelease}' 2>/dev/null || true)"
  printf '%-16s %-55s\n' staging "$(kubectl get releasebinding payments-service-staging -n "$NS" -o jsonpath='{.spec.componentRelease}' 2>/dev/null || echo '<not promoted>')"
  printf '%-16s %-55s\n' production "$(kubectl get releasebinding payments-service-production -n "$NS" -o jsonpath='{.spec.componentRelease}' 2>/dev/null || echo '<not promoted>')"
}

log "DeploymentPipeline platform-standard"
kubectl get deploymentpipeline platform-standard -n "$NS" -o yaml | sed -n '1,120p'

log "Immutable payments release selected: $release"
show_bindings

log "Promoting the complete financial slice to staging"
"$ROOT/scripts/promote.sh" staging financial

staging_release="$(kubectl get releasebinding payments-service-staging -n "$NS" -o jsonpath='{.spec.componentRelease}')"
[[ "$staging_release" == "$release" ]] || die "Staging did not receive the expected immutable payments release"
show_bindings

log "Executing regulated production release gate"
"$ROOT/scripts/run-regulated-release-gate.sh" pass production "$release"

log "Promoting the complete financial slice to production"
"$ROOT/scripts/promote.sh" production financial

production_release="$(kubectl get releasebinding payments-service-production -n "$NS" -o jsonpath='{.spec.componentRelease}')"
[[ "$production_release" == "$release" ]] || die "Production did not receive the expected immutable payments release"
show_bindings

log "IMMUTABLE RELEASE PROMOTION: PASS"
echo "payments-service ComponentRelease $release is pinned through development -> staging -> production"
