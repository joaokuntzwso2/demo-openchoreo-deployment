#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
mkdir -p "$ROOT/runtime"

on_error(){ rc=$?; warn "Bootstrap stopped at line ${BASH_LINENO[0]} (exit $rc). Running focused diagnostics."; "$ROOT/scripts/doctor.sh" || true; exit "$rc"; }
trap on_error ERR

"$ROOT/scripts/preflight.sh"
"$ROOT/scripts/prepare-host.sh"
"$ROOT/scripts/install-openchoreo.sh"
"$ROOT/scripts/reconcile-openchoreo-auth.sh"
ensure_demo_context
"$ROOT/scripts/start-webhook-receiver.sh"

log "Applying additive data-plane RBAC required by the regulated-platform ProjectType"
kubectl apply -f "$ROOT/platform/00-platform-projecttype-dataplane-rbac.yaml"
for check in 'patch resourcequotas' 'create resourcequotas' 'patch limitranges' 'create limitranges' 'patch networkpolicies.networking.k8s.io' 'create networkpolicies.networking.k8s.io' 'patch roles.rbac.authorization.k8s.io' 'create roles.rbac.authorization.k8s.io'; do
  verb="${check%% *}"; resource="${check#* }"
  kubectl auth can-i "$verb" "$resource" --as=system:serviceaccount:openchoreo-data-plane:cluster-agent-dataplane | grep -q '^yes$' || die "Data-plane cluster-agent cannot $verb $resource"
done

log "Applying platform application abstractions"
kubectl apply -f "$ROOT/platform/00-namespace.yaml"
kubectl apply -f "$ROOT/platform/01-regulated-platform-project-type.yaml"
kubectl apply -f "$ROOT/platform/02-environments-pipeline.yaml"
kubectl apply -f "$ROOT/platform/03-projects-and-bindings.yaml"
kubectl apply -f "$ROOT/platform/04-alert-notification-channels.yaml"
kubectl apply -f "$ROOT/platform/05-resource-type.yaml"
kubectl apply -f "$ROOT/platform/06-payment-cache.yaml"
kubectl apply -f "$ROOT/platform/authz/roles-bindings.yaml"
kubectl apply -f "$ROOT/platform/07-platform-policy-workflow.yaml"
kubectl apply -f "$ROOT/platform/09-bank-runtime-hardening-trait.yaml"
kubectl apply -f "$ROOT/platform/10-regulated-release-gate-clusterworkflow.yaml"
kubectl apply -f "$ROOT/platform/11-regulated-service-clustercomponenttype.json"
kubectl apply -f "$ROOT/platform/08-k8s-ops-rbac.yaml"

log "Waiting for all 30 platform Project cells"
auto_pin_project_bindings
wait_all_project_cells 540

log "Provisioning the Payments development cache"
pin_resource payment-idempotency-cache development

log "Ensuring all 19 application images exist inside k3d containerd"
"$ROOT/scripts/ensure-app-images.sh"

wait_component(){ local name="$1"; wait_exists component "$name" "$NS" 120; wait_ready releasebinding "${name}-development" "$NS" 360; }

log "Deploying financial domain foundations"
kubectl apply -f "$ROOT/platform/components/customer.yaml"
kubectl apply -f "$ROOT/platform/components/risk.yaml"
kubectl apply -f "$ROOT/platform/components/compliance.yaml"
for c in accounts-service customer-mcp fraud-service risk-mcp compliance-service compliance-mcp; do wait_component "$c"; done

log "Deploying payment orchestration"
kubectl apply -f "$ROOT/platform/components/payments.yaml"
wait_component payments-service

log "Applying Payments SRE/FinOps observability configuration"
cat > "$ROOT/runtime/payments-releasebinding-patch.json" <<'JSON'
{"spec":{"componentTypeEnvironmentConfigs":{"resources":{"requests":{"cpu":"500m","memory":"400Mi"},"limits":{"cpu":"1000m","memory":"700Mi"}}},"traitEnvironmentConfigs":{"payment-error-rca":{"enabled":true,"actions":{"notifications":{"channels":["platform-webhook-development"]},"incident":{"enabled":true,"triggerAiRca":true}}},"payment-cpu-watch":{"enabled":true,"actions":{"notifications":{"channels":["platform-webhook-development"]},"incident":{"enabled":false}}},"payment-budget-finops":{"enabled":true,"actions":{"notifications":{"channels":["platform-webhook-development"]},"incident":{"enabled":true,"triggerAiCostAnalysis":true}}}}}}
JSON
kubectl patch releasebinding payments-service-development -n "$NS" --type=merge --patch-file "$ROOT/runtime/payments-releasebinding-patch.json" >/dev/null
wait_ready releasebinding payments-service-development "$NS" 360

log "Deploying the financial experience and operations agent"
kubectl apply -f "$ROOT/platform/components/experience.yaml"
wait_component financial-bff
wait_component financial-agent

log "Deploying telecom runtime Components"
kubectl apply -f "$ROOT/platform/components/telco.yaml"
# Foundation services first. OpenChoreo dependency resolution gates dependent workloads.
for c in telco-subscriber-service telco-legacy-billing telco-network-service telco-commercial-service telco-policy-service; do wait_component "$c"; done
for c in telco-bss-facade telco-mcp telco-portal; do wait_component "$c"; done

log "Publishing demo APIs to the OpenChoreo API catalog"
"$ROOT/scripts/seed-api-catalog.sh"

log "Deploying the Kubernetes Operations Console with live in-cluster API access"
"$ROOT/scripts/apply-ops-rbac.sh"
kubectl apply -f "$ROOT/platform/components/ops.yaml"
wait_component k8s-ops-console

log "Deploying the unified Platform Application Portal"
kubectl apply -f "$ROOT/platform/components/platform-portal.yaml"
wait_component platform-portal

log "Final convergence check: all 19 development ReleaseBindings"
for c in accounts-service customer-mcp fraud-service risk-mcp compliance-service compliance-mcp payments-service financial-bff financial-agent platform-portal telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal k8s-ops-console; do
  wait_ready releasebinding "${c}-development" "$NS" 360
done

if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then
  log "Starting optional Rancher management cluster"
  "$ROOT/scripts/rancher.sh" up
fi
log "Loading deterministic financial scenarios"
"$ROOT/scripts/bootstrap-data.sh"
log "Loading deterministic telecom scenarios"
"$ROOT/scripts/bootstrap-telco-data.sh"
"$ROOT/scripts/wait-openchoreo-catalog.sh"


# Platform Artifacts UI extension
if [[ "${ENABLE_PLATFORM_ARTIFACTS_UI:-1}" == "1" ]]; then
  [[ -x "$ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh" ]] || die "Platform Artifacts UI extension is enabled but missing from extensions/platform-artifacts-ui"
  log "Ensuring architecture-native OpenChoreo Platform Artifacts UI"
  "$ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh"
fi

"$ROOT/scripts/status.sh"
log "Platform application bootstrap complete"
printf '\nOpenChoreo: http://openchoreo.localhost:8080\n'
if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then
  printf 'Rancher: https://rancher.localhost:8444/dashboard/\n'
else
  printf 'Rancher: disabled (optional)\n'
fi
for c in platform-portal financial-bff financial-agent telco-portal telco-mcp k8s-ops-console telco-subscriber-service telco-network-service telco-bss-facade; do
  u="$(external_url "$c" || true)"; [[ -n "$u" ]] && printf '%-28s %s\n' "$c:" "$u"
done
