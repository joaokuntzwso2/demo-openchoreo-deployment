#!/usr/bin/env bash
set -u
source "$(dirname "$0")/lib.sh"
need kubectl; need python3

log "Kubernetes/OpenChoreo context"
kubectl config current-context || true
kubectl get clusterdataplane,clusterworkflowplane,clusterobservabilityplane 2>/dev/null || true

log "Platform application control-plane objects"
kubectl get project,projectreleasebinding,resource,resourcereleasebinding,component,workload,componentrelease,releasebinding -n "$NS" 2>/dev/null || true

log "Objects that are not Ready"
for kind in projectreleasebinding resourcereleasebinding component releasebinding; do
  kubectl get "$kind" -n "$NS" -o json 2>/dev/null | python3 -c '
import json,sys
kind=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for x in d.get("items",[]):
    cs=x.get("status",{}).get("conditions") or []
    if any(c.get("type")=="Ready" and c.get("status")=="True" for c in cs):
        continue
    print()
    print("{}/{} generation={} observed={}".format(kind, x["metadata"]["name"], x["metadata"].get("generation"), x.get("status",{}).get("observedGeneration")))
    for c in cs:
        print("  {}={} reason={} message={}".format(c.get("type"), c.get("status"), c.get("reason",""), c.get("message","")))
' "$kind" || true
done

log "Rendered releases"
kubectl get renderedrelease -A 2>/dev/null | grep -E "$NS|platform|payment|customer|risk|compliance|financial|telco|ops" || true

log "Platform application data-plane workloads"
kubectl get pods,deploy,statefulset,svc,httproute,networkpolicy -A -l openchoreo.dev/namespace="$NS" 2>/dev/null || \
  kubectl get pods,deploy,statefulset,svc,httproute,networkpolicy -A 2>/dev/null | grep -E 'dp-platform-demo|accounts|payments|fraud|risk|compliance|customer|valkey|financial|telco|k8s-ops|platform-portal' || true

log "Recent warning events"
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -n 60 || true

log "Controller tail"
kubectl logs -n openchoreo-control-plane deploy/controller-manager --tail=100 2>/dev/null | grep -Ei 'error|fail|platform-demo|render|release|binding' | tail -n 80 || true

log "Observability/AI pods"
kubectl get pods -n openchoreo-observability-plane 2>/dev/null || true
kubectl get pods -n openchoreo-control-plane 2>/dev/null | grep -E 'backstage|portal-assistant|openchoreo-api|controller' || true

log "External routes"
for c in platform-portal financial-bff financial-agent telco-portal k8s-ops-console; do printf '%s: %s\n' "$c" "$(external_url "$c" 2>/dev/null || echo pending)"; done
