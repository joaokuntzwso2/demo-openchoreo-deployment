#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REPORT="${SHOWCASE_CAPABILITY_REPORT:-runtime/showcase-capabilities.md}"
mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"

FAILURES=0
WARNINGS=0

emit() {
  printf '%s\n' "$*" | tee -a "$REPORT"
}

pass() {
  emit "- PASS — $*"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  emit "- WARN — $*"
}

fail() {
  FAILURES=$((FAILURES + 1))
  emit "- FAIL — $*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

count_resource() {
  local resource="$1"
  local namespace="${2:-}"
  local out

  if [[ -n "$namespace" ]]; then
    out="$(kubectl get "$resource" -n "$namespace" -o name 2>/dev/null || true)"
  else
    out="$(kubectl get "$resource" -A -o name 2>/dev/null || true)"
  fi

  if [[ -z "$out" ]]; then
    printf '0'
  else
    printf '%s\n' "$out" | awk 'NF {n++} END {print n+0}'
  fi
}

object_exists() {
  local resource="$1"
  local name="$2"
  local namespace="${3:-}"

  if [[ -n "$namespace" ]]; then
    kubectl get "$resource" "$name" -n "$namespace" >/dev/null 2>&1
  else
    kubectl get "$resource" "$name" >/dev/null 2>&1
  fi
}

check_count() {
  local label="$1"
  local resource="$2"
  local expected="$3"
  local namespace="${4:-}"
  local actual
  actual="$(count_resource "$resource" "$namespace")"

  if [[ "$actual" == "$expected" ]]; then
    pass "$label: $actual"
  else
    fail "$label: expected $expected, found $actual"
  fi
}

check_object() {
  local label="$1"
  local resource="$2"
  local name="$3"
  local namespace="${4:-}"

  if object_exists "$resource" "$name" "$namespace"; then
    pass "$label: $name"
  else
    fail "$label missing: $name"
  fi
}

emit "# OpenChoreo live capability evidence"
emit
emit "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
emit
emit "This report proves the platform state used by the showcase. It intentionally separates OpenChoreo platform capabilities from Kubernetes/Rancher runtime visibility."
emit

if ! have kubectl; then
  fail "kubectl is not installed"
  emit
  emit "Result: FAILED"
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  fail "Kubernetes cluster is not reachable"
  emit
  emit "Result: FAILED"
  exit 1
fi

NS="${OPENCHOREO_DEMO_NAMESPACE:-platform-demo}"

emit "## Platform topology"
check_count "Projects" "projects.openchoreo.dev" 10 "$NS"
check_count "Components" "components.openchoreo.dev" 19 "$NS"
check_count "ProjectReleaseBindings" "projectreleasebindings.openchoreo.dev" 30 "$NS"
check_object "Development environment" "environments.openchoreo.dev" "development" "$NS"
check_object "Staging environment" "environments.openchoreo.dev" "staging" "$NS"
check_object "Production environment" "environments.openchoreo.dev" "production" "$NS"
check_object "Deployment pipeline" "deploymentpipelines.openchoreo.dev" "platform-standard" "$NS"

emit
emit "## Platform engineering and governance"
check_object "Regulated golden path / ProjectType" "clusterprojecttypes.openchoreo.dev" "regulated-platform"
check_object "Managed cache ResourceType" "clusterresourcetypes.openchoreo.dev" "platform-valkey-cache"
check_object "Managed payment cache resource" "resources.openchoreo.dev" "payment-idempotency-cache" "$NS"
check_object "Policy workflow" "workflows.openchoreo.dev" "platform-policy-gate" "$NS"
check_object "Platform auditor role" "authzroles.openchoreo.dev" "platform-auditor" "$NS"
check_object "Developer scoped authorization binding" "clusterauthzrolebindings.openchoreo.dev" "platform-demo-developers"
check_object "Auditor authorization binding" "authzrolebindings.openchoreo.dev" "platform-demo-auditors" "$NS"

emit
emit "## OpenChoreo planes"
for r in \
  clusterdataplanes.openchoreo.dev \
  clusterworkflowplanes.openchoreo.dev \
  clusterobservabilityplanes.openchoreo.dev
do
  n="$(count_resource "$r")"
  if [[ "$n" -ge 1 ]]; then
    pass "$r: $n configured"
  else
    fail "$r: none configured"
  fi
done

emit
emit "## Observability and operations"
CHANNELS="$(count_resource "observabilityalertsnotificationchannels.openchoreo.dev" "$NS")"
if [[ "$CHANNELS" -ge 3 ]]; then
  pass "Alert notification channels: $CHANNELS"
else
  warn "Expected environment-specific alert channels; found $CHANNELS"
fi

PAYMENTS_COMPONENT_JSON="$(kubectl get components.openchoreo.dev payments-service -n "$NS" -o json 2>/dev/null || true)"
PAYMENTS_RB_JSON="$(kubectl get releasebindings.openchoreo.dev payments-service-development -n "$NS" -o json 2>/dev/null || true)"
PAYMENTS_ALERTS_JSON="$(kubectl get observabilityalertrules.openchoreo.dev -A -o json 2>/dev/null || true)"

PAYMENTS_OBS_JSON="${PAYMENTS_COMPONENT_JSON}
${PAYMENTS_RB_JSON}
${PAYMENTS_ALERTS_JSON}"

for evidence in "budget" "cpu"; do
  if grep -qi "$evidence" <<<"$PAYMENTS_OBS_JSON"; then
    pass "Payments observability evidence contains '$evidence'"
  else
    warn "Payments observability evidence '$evidence' was not found"
  fi
done

if grep -qi "triggerAiRca" <<<"$PAYMENTS_OBS_JSON"; then
  pass "Payments alerting is configured for AI-assisted RCA"
else
  warn "Payments alerting does not currently expose triggerAiRca"
fi

emit
emit "## Agentic platform operations"
CONTROL_NS="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
OBS_NS="${OPENCHOREO_OBSERVABILITY_PLANE_NAMESPACE:-openchoreo-observability-plane}"

for pair in \
  "$CONTROL_NS:portal-assistant:Portal Assistant" \
  "$OBS_NS:sre-agent:SRE Agent" \
  "$OBS_NS:finops-agent:FinOps Agent"
do
  IFS=: read -r ns dep label <<<"$pair"
  if kubectl get deployment "$dep" -n "$ns" >/dev/null 2>&1; then
    ready="$(kubectl get deployment "$dep" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    desired="$(kubectl get deployment "$dep" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
    ready="${ready:-0}"
    desired="${desired:-0}"
    if [[ "$desired" -gt 0 && "$ready" -ge "$desired" ]]; then
      pass "$label: ready ($ready/$desired)"
    else
      warn "$label exists but is not fully ready ($ready/$desired)"
    fi
  else
    warn "$label is not enabled in this runtime"
  fi
done

emit
emit "## Kubernetes and SUSE Rancher evidence"
OPS_DEP="$(kubectl get deployment -A -o name 2>/dev/null | grep -E 'k8s-ops|kubernetes-ops' | head -1 || true)"
if [[ -n "$OPS_DEP" ]]; then
  pass "Kubernetes Operations Console deployment is present"
else
  warn "Kubernetes Operations Console deployment was not located automatically"
fi

if command -v docker >/dev/null 2>&1 && docker inspect platform-rancher >/dev/null 2>&1; then
  RANCHER_RUNNING="$(docker inspect -f '{{.State.Running}}' platform-rancher 2>/dev/null || true)"
  RANCHER_IMAGE_LIVE="$(docker inspect -f '{{.Config.Image}}' platform-rancher 2>/dev/null || true)"
  if [[ "$RANCHER_RUNNING" == "true" ]]; then
    pass "SUSE Rancher container is running ($RANCHER_IMAGE_LIVE)"
  else
    fail "SUSE Rancher container exists but is not running"
  fi

  if "$ROOT/scripts/rancher.sh" verify >/dev/null 2>&1; then
    pass "Rancher can reach the imported OpenChoreo Kubernetes cluster"
  else
    warn "Rancher is running but imported-cluster verification did not pass"
  fi
else
  warn "SUSE Rancher container is not running"
fi

emit
emit "## Result"
if [[ "$FAILURES" -eq 0 ]]; then
  emit "READY — ${WARNINGS} warning(s)."
  emit
  emit "OpenChoreo remains the developer-platform/control-plane story; Rancher provides complementary Kubernetes fleet/runtime visibility."
  exit 0
else
  emit "NOT READY — ${FAILURES} failure(s), ${WARNINGS} warning(s)."
  exit 1
fi
