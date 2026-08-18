#!/usr/bin/env bash
set -Eeuo pipefail

EXT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_ROOT="${1:-$(cd "$EXT_ROOT/../.." && pwd)}"
DEMO_ROOT="$(cd "$DEMO_ROOT" && pwd)"

[[ -f "$DEMO_ROOT/demo.sh" ]] || { echo "ERROR: '$DEMO_ROOT' is not demo-openchoreo-deployment" >&2; exit 1; }

echo "==> Embedding Platform Artifacts ownership metadata into committed manifests"
python3 "$EXT_ROOT/scripts/patch-custom-artifact-metadata.py" "$DEMO_ROOT"
python3 "$EXT_ROOT/scripts/patch-custom-artifact-metadata.py" "$DEMO_ROOT" --check

echo "==> Reconciling the already-running OpenChoreo objects"
"$EXT_ROOT/scripts/label-demo-artifacts.sh"

echo "==> Verifying the enhanced OpenChoreo portal and metadata"
"$EXT_ROOT/scripts/verify-platform-artifacts-ui.sh"

echo
echo "==> Repair complete"
echo "    Refresh: http://openchoreo.localhost:8080/platform-artifacts"
echo "    The page auto-refreshes; a browser hard refresh is safe if it was already open."
