#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_ROOT="${1:-$PWD}"
DEMO_ROOT="$(cd "$DEMO_ROOT" && pwd)"

"$ROOT/scripts/install-into-demo-repo.sh" "$DEMO_ROOT"

CLUSTER="${OPENCHOREO_CLUSTER_NAME:-openchoreo-quick-start}"
if command -v k3d >/dev/null 2>&1 && k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "$CLUSTER"; then
  echo
  echo "==> Existing OpenChoreo cluster detected; reconciling live Platform Artifacts metadata"
  k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context >/dev/null

  CURRENT_IMAGE="$(kubectl get deployment backstage -n openchoreo-control-plane -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
  if [[ "$CURRENT_IMAGE" == openchoreo-ui-platform-artifacts:* ]]; then
    # The current v2/v3 portal code already performs dynamic discovery. No costly
    # rebuild is required merely to repair ownership labels.
    "$DEMO_ROOT/extensions/platform-artifacts-ui/scripts/repair-platform-artifacts-metadata.sh" "$DEMO_ROOT"
  else
    echo "==> Custom portal is not active yet; running full architecture-aware ensure"
    "$DEMO_ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh"
  fi
else
  echo
  echo "==> No running OpenChoreo cluster detected. Repository integration is complete."
  echo "    Customer/fresh-clone start command:"
  echo "      cd $DEMO_ROOT"
  echo "      ./demo.sh reset"
fi
