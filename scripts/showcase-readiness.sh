#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ -f .showcase.env ]] && source .showcase.env

echo "==> 1/5 Source and manifest self-test"
./scripts/self-test.sh

echo
echo "==> 2/5 Clean-room/runtime verification"
./demo.sh verify

echo
echo "==> 3/5 Auth and catalog readiness"
./scripts/reconcile-openchoreo-auth.sh
./scripts/wait-openchoreo-catalog.sh

echo
echo "==> 4/5 Rancher"
if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then
  ./scripts/rancher.sh verify
else
  echo "SKIP: Rancher is disabled (optional)"
fi

echo
echo "==> 5/5 OpenChoreo capability proof"
./scripts/showcase-capabilities.sh
./scripts/verify-platform-engineering.sh

echo
echo "SHOWCASE READINESS: PASS"
