#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .showcase.env ]]; then
  # shellcheck disable=SC1091
  source .showcase.env
fi

echo "==> 1/5 Source and manifest self-test"
./scripts/self-test.sh

echo
echo "==> 2/5 Clean-room/runtime verification"
./demo.sh verify

echo
echo "==> 3/5 Event-determinism checks"
if [[ "${SHOWCASE_STRICT:-0}" == "1" ]]; then
  if [[ -z "${RANCHER_IMAGE:-}" ]]; then
    echo "ERROR: SHOWCASE_STRICT=1 but RANCHER_IMAGE is unset." >&2
    exit 1
  fi
  if [[ "$RANCHER_IMAGE" == *":latest" ]]; then
    echo "ERROR: SHOWCASE_STRICT=1 refuses a mutable Rancher :latest tag." >&2
    echo "Run: ./scripts/showcase-freeze-rancher.sh" >&2
    exit 1
  fi
  if [[ "$RANCHER_IMAGE" != *@sha256:* ]]; then
    echo "ERROR: SHOWCASE_STRICT=1 requires Rancher to be pinned by digest." >&2
    exit 1
  fi
  echo "PASS: Rancher image is immutable: $RANCHER_IMAGE"
else
  echo "WARN: SHOWCASE_STRICT is not enabled; suitable for development, not event qualification."
fi

echo
echo "==> 4/5 SUSE Rancher verification"
if [[ "${SHOWCASE_REQUIRE_RANCHER:-${RANCHER_REQUIRED:-0}}" == "1" ]]; then
  ./scripts/rancher.sh verify
else
  ./scripts/rancher.sh verify || echo "WARN: Rancher verification is optional in this run."
fi

echo
echo "==> 5/5 OpenChoreo capability proof"
./scripts/showcase-capabilities.sh

echo
echo "==> OpenChoreo platform-engineering proof"
./scripts/verify-platform-engineering.sh

if [[ "${SHOWCASE_REQUIRE_AI:-0}" == "1" ]]; then
  echo
  echo "==> Required AI-agent readiness"
  kubectl rollout status deployment/portal-assistant -n "${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}" --timeout=120s
  kubectl rollout status deployment/sre-agent -n "${OPENCHOREO_OBSERVABILITY_PLANE_NAMESPACE:-openchoreo-observability-plane}" --timeout=120s
  kubectl rollout status deployment/finops-agent -n "${OPENCHOREO_OBSERVABILITY_PLANE_NAMESPACE:-openchoreo-observability-plane}" --timeout=120s
fi

echo
echo "SHOWCASE READINESS: PASS"
echo "Evidence: runtime/showcase-capabilities.md"
