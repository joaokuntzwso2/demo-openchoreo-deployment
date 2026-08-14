#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
log "1/6 OpenChoreo abstractions (developer intent)"
kubectl get project,component,workload,resource -n "$NS"
log "2/6 Release objects (immutable desired state + environment bindings)"
kubectl get componentrelease,releasebinding,resourcerelease,resourcereleasebinding,projectrelease,projectreleasebinding -n "$NS" 2>/dev/null || true
log "3/6 Cell namespaces generated per project/environment"
kubectl get ns -l openchoreo.dev/namespace="$NS" --show-labels || kubectl get ns | grep 'dp-platform-demo'
log "4/6 Workloads rendered to native Kubernetes"
kubectl get deploy,statefulset,pod -A | grep -E 'accounts|payments|fraud|compliance|mcp|valkey|financial|telco|k8s-ops|platform-portal' || true
log "5/6 Security and networking rendered to Kubernetes"
kubectl get networkpolicy,resourcequota,limitrange,httproute -A | grep -E 'platform-demo|payments|risk|customer|compliance|telco|experience|platform-ops' || true
log "6/6 OpenChoreo controllers/agents across planes"
kubectl get pods -A | grep -E 'openchoreo|backstage|argo|workflow|observer|opensearch|prometheus|gateway|finops|rca' || true
