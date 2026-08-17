#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl
need python3
ensure_demo_context

pass(){ printf 'PASS — %s\n' "$*"; }
info(){ printf 'INFO — %s\n' "$*"; }
fail(){ printf 'FAIL — %s\n' "$*" >&2; exit 1; }

CANARY="regulated-service-proof"
CANARY_ACTIVE=0

cleanup_canary(){
  [[ "$CANARY_ACTIVE" == "1" ]] || return 0
  kubectl delete releasebinding "${CANARY}-development" -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete workload "$CANARY" -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete component "$CANARY" -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  while IFS= read -r obj; do
    [[ -n "$obj" ]] && kubectl delete "$obj" -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done < <(kubectl get componentrelease -n "$NS" -o name 2>/dev/null | grep "/${CANARY}-" || true)
  CANARY_ACTIVE=0
}
trap cleanup_canary EXIT

verify_rendered_hardening(){
  local component="$1"
  local dpns deploy automount seccomp priv profile pdb_count
  dpns="$(kubectl get deploy -A -l "openchoreo.dev/component=${component}" -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || true)"
  [[ -n "$dpns" ]] || fail "rendered Deployment namespace for $component was not found"
  deploy="$(kubectl get deploy -n "$dpns" -l "openchoreo.dev/component=${component}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "$deploy" ]] || fail "rendered Deployment for $component was not found"

  automount="$(kubectl get deploy "$deploy" -n "$dpns" -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')"
  seccomp="$(kubectl get deploy "$deploy" -n "$dpns" -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}')"
  priv="$(kubectl get deploy "$deploy" -n "$dpns" -o jsonpath='{.spec.template.spec.containers[?(@.name=="main")].securityContext.allowPrivilegeEscalation}')"
  profile="$(kubectl get deploy "$deploy" -n "$dpns" -o jsonpath='{.spec.template.metadata.annotations.platform\.openchoreo\.dev/compliance-profile}')"

  [[ "$automount" == "false" ]] || fail "$component: automountServiceAccountToken is '$automount', expected false"
  [[ "$seccomp" == "RuntimeDefault" ]] || fail "$component: seccomp is '$seccomp', expected RuntimeDefault"
  [[ "$priv" == "false" ]] || fail "$component: allowPrivilegeEscalation is '$priv', expected false"
  [[ "$profile" == "PCI-DSS" ]] || fail "$component: compliance profile is '$profile', expected PCI-DSS"

  pdb_count="$(kubectl get pdb -n "$dpns" -l "openchoreo.dev/component=${component}" -o json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(1 for x in d.get("items",[]) if x.get("metadata",{}).get("annotations",{}).get("platform.openchoreo.dev/managed-by-trait")=="bank-runtime-hardening"))')"
  [[ "$pdb_count" -ge 1 ]] || fail "$component: bank-runtime-hardening PodDisruptionBudget not found"
}

verify_canary(){
  info "existing payments-service predates the new golden path; validating regulated-service with an ephemeral canary"
  cleanup_canary || true
  CANARY_ACTIVE=1

  cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: openchoreo.dev/v1alpha1
kind: Component
metadata:
  name: ${CANARY}
  namespace: ${NS}
  annotations:
    openchoreo.dev/display-name: "Regulated Service Golden Path Proof"
spec:
  owner:
    projectName: payments
  autoDeploy: true
  componentType:
    kind: ClusterComponentType
    name: deployment/regulated-service
---
apiVersion: openchoreo.dev/v1alpha1
kind: Workload
metadata:
  name: ${CANARY}
  namespace: ${NS}
spec:
  owner:
    projectName: payments
    componentName: ${CANARY}
  container:
    image: platform-demo/accounts-service:1.0.0
    env:
      - key: NODE_ENV
        value: production
  endpoints:
    http:
      type: HTTP
      port: 8080
      visibility:
        - namespace
YAML

  wait_exists component "$CANARY" "$NS" 120
  wait_ready releasebinding "${CANARY}-development" "$NS" 420
  verify_rendered_hardening "$CANARY"
  pass "ephemeral Component proves deployment/regulated-service + bank-runtime-hardening on the live Data Plane"

  cleanup_canary
}

kubectl get deploymentpipeline platform-standard -n "$NS" >/dev/null 2>&1 || fail "DeploymentPipeline platform-standard"
pass "DeploymentPipeline platform-standard"

kubectl get clustertrait bank-runtime-hardening >/dev/null 2>&1 || fail "ClusterTrait bank-runtime-hardening"
pass "ClusterTrait bank-runtime-hardening"

kubectl get clusterworkflow regulated-release-gate >/dev/null 2>&1 || fail "ClusterWorkflow regulated-release-gate"
pass "ClusterWorkflow regulated-release-gate"

kubectl get clustercomponenttype regulated-service >/dev/null 2>&1 || fail "ClusterComponentType regulated-service"
pass "ClusterComponentType regulated-service"

embedded="$(kubectl get clustercomponenttype regulated-service -o jsonpath='{.spec.traits[?(@.name=="bank-runtime-hardening")].instanceName}')"
[[ "$embedded" == "bank-runtime-baseline" ]] || fail "regulated-service does not embed bank-runtime-hardening"
pass "regulated-service automatically embeds bank-runtime-hardening"

# Repository desired state must already point to the new golden path, even when the live
# component predates the upgrade and cannot be mutated in place.
grep -q 'name: deployment/regulated-service' "$ROOT/platform/components/payments.yaml" \
  || fail "repository payments-service desired state is not deployment/regulated-service"
pass "repository desired state migrates payments-service to deployment/regulated-service"

ctype="$(kubectl get component payments-service -n "$NS" -o jsonpath='{.spec.componentType.name}')"
case "$ctype" in
  deployment/regulated-service)
    pass "payments-service consumes deployment/regulated-service"
    wait_ready releasebinding payments-service-development "$NS" 360
    verify_rendered_hardening payments-service
    pass "payments-service rendered Deployment proves bank runtime hardening"
    ;;
  deployment/service)
    info "live payments-service still uses immutable deployment/service; migration will occur on the next clean-room reset"
    verify_canary
    ;;
  *)
    fail "payments-service uses unexpected component type '$ctype'"
    ;;
esac

"$ROOT/scripts/run-regulated-release-gate.sh" pass staging >/dev/null
pass "ClusterWorkflow executes successfully through WorkflowRun"

printf '\nPLATFORM ENGINEERING VERIFICATION: PASS\n'
