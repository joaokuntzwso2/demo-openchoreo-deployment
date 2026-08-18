#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${PLATFORM_ARTIFACTS_NAMESPACE:-platform-demo}"
LABEL_KEY="demo.openchoreo.dev/custom-artifact"
DISPLAY_KEY="demo.openchoreo.dev/display-name"
DESCRIPTION_KEY="demo.openchoreo.dev/description"
CATEGORY_KEY="demo.openchoreo.dev/category"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is required" >&2; exit 1; }; }
need kubectl

# macOS ships an older Bash. Under `set -u`, expanding an empty local array can
# raise "unbound variable" on those versions. Keep cluster-scoped and
# namespace-scoped kubectl calls explicit instead of relying on an empty array.
kget() {
  local resource="$1" name="$2" namespace="$3"; shift 3
  if [[ -n "$namespace" ]]; then
    kubectl get "$resource" "$name" -n "$namespace" "$@"
  else
    kubectl get "$resource" "$name" "$@"
  fi
}

klabel() {
  local resource="$1" name="$2" namespace="$3"; shift 3
  if [[ -n "$namespace" ]]; then
    kubectl label "$resource" "$name" -n "$namespace" "$@"
  else
    kubectl label "$resource" "$name" "$@"
  fi
}

kannotate() {
  local resource="$1" name="$2" namespace="$3"; shift 3
  if [[ -n "$namespace" ]]; then
    kubectl annotate "$resource" "$name" -n "$namespace" "$@"
  else
    kubectl annotate "$resource" "$name" "$@"
  fi
}

mark() {
  local resource="$1" name="$2" namespace="$3" display="$4" category="$5" description="$6"

  if ! kget "$resource" "$name" "$namespace" >/dev/null 2>&1; then
    echo "ERROR: expected OpenChoreo artifact $resource/$name was not found" >&2
    return 1
  fi

  klabel "$resource" "$name" "$namespace" "$LABEL_KEY=true" --overwrite >/dev/null
  kannotate "$resource" "$name" "$namespace" \
    "$DISPLAY_KEY=$display" \
    "$CATEGORY_KEY=$category" \
    "$DESCRIPTION_KEY=$description" \
    --overwrite >/dev/null

  local value
  value="$(kget "$resource" "$name" "$namespace" -o jsonpath='{.metadata.labels.demo\.openchoreo\.dev/custom-artifact}')"
  [[ "$value" == "true" ]] || { echo "ERROR: $resource/$name did not persist $LABEL_KEY=true" >&2; return 1; }
  printf '  marked %-64s %s\n' "$resource/$name" "$category"
}

echo "==> Reconciling demo-owned OpenChoreo Platform Artifacts metadata"
mark clusterprojecttypes.openchoreo.dev regulated-platform "" "Regulated Platform" "Golden Path" "Project golden path that materializes regulated environment cells with quotas, defaults, networking and audit controls."
mark clustercomponenttypes.openchoreo.dev regulated-service "" "Regulated Service" "Golden Path" "Reusable service golden path that composes deployment behavior with the bank runtime hardening trait."
mark clustertraits.openchoreo.dev bank-runtime-hardening "" "Bank Runtime Hardening" "Security & Runtime Policy" "Reusable runtime security baseline including seccomp, capability drop, privilege restrictions and disruption protection."
mark clusterresourcetypes.openchoreo.dev platform-valkey-cache "" "Platform Valkey Cache" "Managed Resource" "Platform-managed Valkey resource abstraction consumed through OpenChoreo resource bindings."
mark clusterworkflows.openchoreo.dev regulated-release-gate "" "Regulated Release Gate" "Governance Workflow" "Reusable release control validating security, risk, change-ticket and approval evidence."

mark workflows.openchoreo.dev platform-policy-gate "$NAMESPACE" "Platform Policy Gate" "Governance Workflow" "Namespace-scoped release policy workflow used to demonstrate policy evidence and rejection paths."
mark deploymentpipelines.openchoreo.dev platform-standard "$NAMESPACE" "Standard Delivery Pipeline" "Delivery" "Development to staging to production delivery topology for the regulated demo projects."
mark resources.openchoreo.dev payment-idempotency-cache "$NAMESPACE" "Payment Idempotency Cache" "Managed Resource Instance" "Managed cache instance consumed by payments-service through an OpenChoreo Resource dependency."

mark environments.openchoreo.dev development "$NAMESPACE" "Development" "Delivery Environment" "OpenChoreo development environment used by the platform-standard delivery pipeline."
mark environments.openchoreo.dev staging "$NAMESPACE" "Staging" "Delivery Environment" "OpenChoreo staging environment used by the platform-standard delivery pipeline."
mark environments.openchoreo.dev production "$NAMESPACE" "Production" "Delivery Environment" "OpenChoreo production environment used by the platform-standard delivery pipeline."

mark observabilityalertsnotificationchannels.openchoreo.dev platform-webhook-development "$NAMESPACE" "Development Alert Webhook" "Observability" "Environment-specific alert notification channel for local showcase evidence."
mark observabilityalertsnotificationchannels.openchoreo.dev platform-webhook-staging "$NAMESPACE" "Staging Alert Webhook" "Observability" "Environment-specific alert notification channel for local showcase evidence."
mark observabilityalertsnotificationchannels.openchoreo.dev platform-webhook-production "$NAMESPACE" "Production Alert Webhook" "Observability" "Environment-specific alert notification channel for local showcase evidence."

mark authzroles.openchoreo.dev platform-auditor "$NAMESPACE" "Platform Auditor" "Access Control" "Read-oriented OpenChoreo role for application, release and observability evidence."
mark clusterauthzrolebindings.openchoreo.dev platform-demo-developers "" "Platform Demo Developers" "Access Control" "Developer authorization binding with environment-aware restrictions around production changes."
mark authzrolebindings.openchoreo.dev platform-demo-auditors "$NAMESPACE" "Platform Demo Auditors" "Access Control" "Binds the showcase auditor subject to the platform-auditor role."

echo "==> Platform Artifacts live metadata reconciliation PASSED"
