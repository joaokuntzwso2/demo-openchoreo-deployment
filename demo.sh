#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/scripts/lib.sh"
cmd="${1:-up}"
case "$cmd" in
  up)
    "$ROOT/scripts/bootstrap-all.sh"
    "$ROOT/scripts/verify-clean-room.sh"
    ;;
  reset)
    "$ROOT/scripts/reset-from-scratch.sh"
    ;;
  verify)
    "$ROOT/scripts/verify-clean-room.sh"
    ;;
  status)
    ensure_demo_context
    "$ROOT/scripts/status.sh"
    "$ROOT/scripts/rancher.sh" status || true
    ;;
  rancher)
    "$ROOT/scripts/rancher.sh" up
    ;;
  scenario)
    shift || true
    "$ROOT/scripts/scenario.sh" "${1:-help}"
    ;;
  stop)
    "$ROOT/scripts/stop-webhook-receiver.sh" || true
    "$ROOT/scripts/rancher.sh" stop || true
    if k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER"; then k3d cluster stop "$CLUSTER"; fi
    ;;
  start)
    k3d cluster start "$CLUSTER"
    ensure_demo_context
    "$ROOT/scripts/start-webhook-receiver.sh"
    "$ROOT/scripts/rancher.sh" start || true
    "$ROOT/scripts/rancher.sh" register || true
    "$ROOT/scripts/status.sh"
    ;;
  destroy)
    "$ROOT/scripts/stop-webhook-receiver.sh" || true
    "$ROOT/scripts/rancher.sh" destroy || true
    k3d cluster delete "$CLUSTER" 2>/dev/null || true
    ;;
  *)
    cat >&2 <<USAGE
Usage: ./demo.sh [up|reset|verify|status|rancher|scenario|stop|start|destroy]

  up       Install/reconcile the complete platform application and verify it (default)
  reset    Destructive clean-room rebuild: OpenChoreo + apps + Rancher + verification
  verify   Run strict end-to-end verification without changing desired state
  status   Show OpenChoreo, Kubernetes application and Rancher status
  rancher  Start/register Rancher against the existing OpenChoreo k3d cluster
  scenario Run a named business/platform demonstration scenario
  stop     Stop the OpenChoreo cluster, Rancher and local webhook receiver
  start    Start a previously stopped local environment
  destroy  Delete the demo k3d cluster and Rancher demo data
USAGE
    exit 2
    ;;
esac
