#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .showcase.env ]]; then
  echo "ERROR: .showcase.env does not exist." >&2
  echo "Freeze a qualified Rancher image first:" >&2
  echo "  ./scripts/showcase-freeze-rancher.sh" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .showcase.env

if [[ "${SHOWCASE_ENABLE_AI:-0}" == "1" ]]; then
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "ERROR: SHOWCASE_ENABLE_AI=1 requires OPENAI_API_KEY." >&2
    exit 1
  fi

  export OPENCHOREO_AGENT_MODEL="${OPENCHOREO_AGENT_MODEL:-gpt-5.4}"
  ./scripts/enable-ai-agents.sh
  export SHOWCASE_REQUIRE_AI=1
fi

./scripts/showcase-readiness.sh

echo
echo "Operator launch points"
echo "----------------------"
./demo.sh status || true
echo
echo "Recommended presentation order:"
echo "  1. Financial business outcome in the custom experience"
echo "  2. OpenChoreo Backstage portal: System/Component views"
echo "  3. ProjectType, cells, releases, resources, authorization, observability"
echo "  4. Policy workflow / promotion"
echo "  5. Kubernetes Operations Console as runtime proof"
echo "  6. SUSE Rancher for the same Kubernetes estate"
echo "  7. SRE / FinOps / Portal Assistant when enabled"
