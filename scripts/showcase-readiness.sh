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
  if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then
    if [[ -z "${RANCHER_IMAGE:-}" ]]; then
      echo "ERROR: ENABLE_RANCHER=1 with SHOWCASE_STRICT=1 requires RANCHER_IMAGE." >&2
      exit 1
    fi

    if [[ "$RANCHER_IMAGE" == *":latest" ]]; then
      echo "ERROR: strict optional Rancher qualification refuses :latest." >&2
      exit 1
    fi

    if [[ "$RANCHER_IMAGE" != *@sha256:* ]]; then
      echo "ERROR: strict optional Rancher qualification requires a digest-pinned image." >&2
      exit 1
    fi

    echo "PASS: optional Rancher image is immutable: $RANCHER_IMAGE"
  else
    echo "PASS: strict OpenChoreo qualification does not require optional Rancher"
  fi
else
  echo "WARN: SHOWCASE_STRICT is not enabled"
fi

echo
echo "==> 4/5 Optional SUSE Rancher verification"

if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then
  ./scripts/rancher.sh verify
else
  echo "SKIP: Rancher is disabled (optional)"
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
