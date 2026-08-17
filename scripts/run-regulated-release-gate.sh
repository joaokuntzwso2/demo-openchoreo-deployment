#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl
ensure_demo_context

mode="${1:-pass}"
environment="${2:-production}"
release="${3:-}"

[[ "$mode" == pass || "$mode" == fail ]] || die "Usage: $0 pass|fail [development|staging|production] [component-release]"
[[ "$environment" == development || "$environment" == staging || "$environment" == production ]] || die "Invalid environment: $environment"

if [[ -z "$release" ]]; then
  release="$(kubectl get component payments-service -n "$NS" -o jsonpath='{.status.latestRelease.name}')"
fi
[[ -n "$release" ]] || die "Could not resolve the latest payments-service ComponentRelease"

suffix="$(date +%H%M%S)-$RANDOM"
run="regulated-gate-${mode}-${suffix}"
if [[ "$mode" == pass ]]; then
  scan="PASS"
  risk="LOW"
  approver="CAB-DEMO"
  ticket="CHG-2026-DEMO"
else
  scan="FAIL"
  risk="HIGH"
  approver="PENDING"
  ticket="CHG-2026-DENIED"
fi

log "Creating WorkflowRun $run against ClusterWorkflow regulated-release-gate"
cat <<YAML | kubectl apply -f -
apiVersion: openchoreo.dev/v1alpha1
kind: WorkflowRun
metadata:
  name: $run
  namespace: $NS
  labels:
    platform.openchoreo.dev/demo-scenario: regulated-release-gate
spec:
  ttlAfterCompletion: 30m
  workflow:
    kind: ClusterWorkflow
    name: regulated-release-gate
    parameters:
      release: "$release"
      environment: "$environment"
      changeTicket: "$ticket"
      securityScan: "$scan"
      riskAssessment: "$risk"
      approvedBy: "$approver"
YAML

log "Waiting for WorkflowRun to complete"
kubectl wait workflowrun "$run" -n "$NS" --for=condition=WorkflowCompleted --timeout=240s >/dev/null

echo
kubectl get workflowrun "$run" -n "$NS" -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" reason="}{.reason}{" message="}{.message}{"\n"}{end}' || true
kubectl get workflowrun "$run" -n "$NS" -o jsonpath='{range .status.tasks[*]}{.name}{"\t"}{.phase}{"\t"}{.message}{"\n"}{end}' || true

succeeded="$(kubectl get workflowrun "$run" -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="WorkflowSucceeded")].status}' 2>/dev/null || true)"
failed="$(kubectl get workflowrun "$run" -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="WorkflowFailed")].status}' 2>/dev/null || true)"

if [[ "$mode" == pass ]]; then
  [[ "$succeeded" == "True" ]] || die "Expected policy gate to succeed, but it did not"
  log "REGULATED RELEASE GATE: PASS"
else
  [[ "$failed" == "True" ]] || die "Expected policy gate to deny the release, but it did not"
  log "EXPECTED POLICY DENIAL: PASS"
fi

echo "WorkflowRun: $NS/$run"
