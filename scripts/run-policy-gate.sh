#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl; need python3
ensure_demo_context
name="platform-policy-gate-$(date +%H%M%S)"
cat <<YAML | kubectl apply -f -
apiVersion: openchoreo.dev/v1alpha1
kind: WorkflowRun
metadata:
  name: $name
  namespace: $NS
spec:
  workflow:
    kind: Workflow
    name: platform-policy-gate
    parameters:
      release: payments-service-demo
      environment: staging
      changeTicket: CHG-2026-0814
      securityScan: PASS
YAML
log "WorkflowRun $name submitted to the OpenChoreo Workflow Plane"
start=$SECONDS
while (( SECONDS-start < 180 )); do
  state="$(kubectl get workflowrun "$name" -n "$NS" -o json 2>/dev/null | python3 -c '
import json,sys
try:x=json.load(sys.stdin)
except Exception: print("Pending"); raise SystemExit
cs={c.get("type"):c.get("status") for c in x.get("status",{}).get("conditions",[]) or []}
if cs.get("WorkflowSucceeded")=="True": print("Succeeded")
elif cs.get("WorkflowFailed")=="True": print("Failed")
elif cs.get("WorkflowRunning")=="True": print("Running")
else: print("Pending")
' || echo Pending)"
  printf '  workflow status: %s (%ss)\n' "$state" "$((SECONDS-start))"
  if [[ "$state" == Succeeded ]]; then
    kubectl get workflowrun "$name" -n "$NS" -o custom-columns='NAME:.metadata.name,STARTED:.status.startedAt,COMPLETED:.status.completedAt'
    kubectl get workflowrun "$name" -n "$NS" -o jsonpath='{range .status.tasks[*]}{.name}{"\t"}{.phase}{"\t"}{.message}{"\n"}{end}' 2>/dev/null || true
    log "Platform policy gate PASSED"
    exit 0
  fi
  if [[ "$state" == Failed ]]; then
    kubectl get workflowrun "$name" -n "$NS" -o yaml | tail -n 100
    die "Platform policy gate failed"
  fi
  sleep 5
done
kubectl get workflowrun "$name" -n "$NS" -o yaml | tail -n 100 || true
die "Platform policy gate did not complete within 180s"
