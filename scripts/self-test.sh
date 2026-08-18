#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf '\n==> Static repository self-test\n'

for f in "$ROOT"/scripts/*.sh "$ROOT/demo.sh"; do bash -n "$f"; done
printf '  shell syntax: PASS\n'
if command -v node >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do node --check "$f" >/dev/null; done < <(find "$ROOT/services" "$ROOT/scripts" -type f -name '*.js' -print0)
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker run --rm --pull=missing -v "$ROOT:/workspace" -w /workspace node:22-alpine sh -c 'find services scripts -type f -name "*.js" -print0 | xargs -0 -n1 node --check >/dev/null'
else
  echo 'Node.js is unavailable and Docker cannot be used for JavaScript syntax validation' >&2; exit 1
fi
printf '  JavaScript syntax: PASS\n'

# Every browser application must preserve the OpenChoreo component route prefix.
uis=(services/financial-bff/index.html services/financial-agent/index.html services/platform-portal/index.html services/telco-portal/index.html services/k8s-ops-console/index.html)
for f in "${uis[@]}"; do
  grep -q 'location.pathname' "$ROOT/$f" || { echo "$f is not OpenChoreo route-prefix aware" >&2; exit 1; }
done
if grep -R -n -E "fetch\(['\"]\/api\/" "${uis[@]/#/$ROOT/}" >/tmp/platform-demo-bad-fetches.$$ 2>/dev/null; then
  cat /tmp/platform-demo-bad-fetches.$$ >&2; rm -f /tmp/platform-demo-bad-fetches.$$; echo 'UI contains root-absolute /api fetches' >&2; exit 1
fi
rm -f /tmp/platform-demo-bad-fetches.$$ 2>/dev/null || true
printf '  OpenChoreo route-prefix-aware UIs: PASS\n'

services=(accounts-service payments-service fraud-service compliance-service financial-bff mcp-customer mcp-risk mcp-compliance financial-agent platform-portal telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal k8s-ops-console)
for svc in "${services[@]}"; do
  [[ -f "$ROOT/services/$svc/Dockerfile" ]] || { echo "Missing services/$svc/Dockerfile" >&2; exit 1; }
  find "$ROOT/services/$svc" -maxdepth 1 -type f \( -name '*.js' -o -name '*.html' \) | grep -q . || { echo "Service $svc has no source file" >&2; exit 1; }
  grep -Rqs "image: platform-demo/${svc}:1.0.0" "$ROOT/platform/components" || { echo "No Workload references platform-demo/${svc}:1.0.0" >&2; exit 1; }
done
printf '  19 service build contexts + Workload image references: PASS\n'

component_count="$(grep -R '^kind: Component$' "$ROOT/platform/components" | wc -l | tr -d ' ')"
workload_count="$(grep -R '^kind: Workload$' "$ROOT/platform/components" | wc -l | tr -d ' ')"
[[ "$component_count" == 19 && "$workload_count" == 19 ]] || { echo "Expected 19 Components + 19 Workloads, got $component_count + $workload_count" >&2; exit 1; }
project_count="$(grep -c '^kind: Project$' "$ROOT/platform/03-projects-and-bindings.yaml" | tr -d ' ')"
prb_count="$(grep -c '^kind: ProjectReleaseBinding$' "$ROOT/platform/03-projects-and-bindings.yaml" | tr -d ' ')"
[[ "$project_count" == 10 && "$prb_count" == 30 ]] || { echo "Expected 10 Projects + 30 bindings, got $project_count + $prb_count" >&2; exit 1; }
printf '  desired-state cardinality (10 Projects / 30 cells / 19 Components): PASS\n'

[[ -f "$ROOT/platform/00-platform-projecttype-dataplane-rbac.yaml" ]] || { echo 'Missing ProjectType data-plane RBAC manifest' >&2; exit 1; }
grep -q 'platform-demo-projecttype-dataplane-applier' "$ROOT/platform/00-platform-projecttype-dataplane-rbac.yaml" || { echo 'Unexpected ProjectType RBAC manifest' >&2; exit 1; }
grep -q 'namespace: ${metadata.namespace}' "$ROOT/platform/07-platform-policy-workflow.yaml" || { echo 'Workflow is missing v1.2-compatible metadata.namespace interpolation' >&2; exit 1; }
printf '  OpenChoreo v1.2 ProjectType/workflow invariants: PASS\n'

if grep -Eq 'local label="\$1" payload="\$2" expect="\$3" outfile=' "$ROOT/scripts/bootstrap-data.sh"; then echo 'bootstrap-data nounset regression detected' >&2; exit 1; fi
if grep -Eq 'local label="\$1" method="\$2" path="\$3".*out="/tmp/platform-telco-\$\{label\}' "$ROOT/scripts/bootstrap-telco-data.sh"; then echo 'bootstrap-telco-data nounset regression detected' >&2; exit 1; fi
rancher_line="$(grep -n 'rancher.sh" up' "$ROOT/scripts/bootstrap-all.sh" | head -1 | cut -d: -f1)"
telco_seed_line="$(grep -n 'bootstrap-telco-data.sh' "$ROOT/scripts/bootstrap-all.sh" | head -1 | cut -d: -f1)"
[[ -n "$rancher_line" && -n "$telco_seed_line" && "$rancher_line" -lt "$telco_seed_line" ]] || { echo 'Rancher must start before scenario seeders' >&2; exit 1; }
grep -q -- '--provenance=false' "$ROOT/scripts/build-images.sh" || { echo 'build-images.sh does not disable provenance' >&2; exit 1; }
grep -q 'ctr -n k8s.io images import' "$ROOT/scripts/build-images.sh" || { echo 'build-images.sh missing direct containerd fallback' >&2; exit 1; }
grep -q 'ensure-app-images.sh' "$ROOT/scripts/bootstrap-all.sh" || { echo 'bootstrap is missing pre-component image verification' >&2; exit 1; }
grep -q 'PLATFORM_DEMO_NO_CACHE=1' "$ROOT/scripts/reset-from-scratch.sh" || { echo 'clean-room reset is not forcing no-cache app builds' >&2; exit 1; }
printf '  deterministic clean-room image/bootstrap invariants: PASS\n'

grep -q 'kubernetes.default.svc' "$ROOT/services/k8s-ops-console/server.js" || { echo 'Kubernetes Ops Console is not using the in-cluster Kubernetes API' >&2; exit 1; }
grep -q 'platform.demo/restartedAt' "$ROOT/services/k8s-ops-console/server.js" || { echo 'Kubernetes Ops Console safe restart action missing' >&2; exit 1; }
grep -q 'rancher/rancher@sha256:5d0354e95d55f92da0f3c0fdcf59c07dacfe5bda886aac5273da4ca98c8c1376' "$ROOT/scripts/rancher.sh" || { echo 'Rancher integration missing or immutable Rancher image is not pinned to the showcase digest' >&2; exit 1; }
if grep -q 'rancher/rancher:v2.12.10' "$ROOT/scripts/rancher.sh"; then
  echo 'Obsolete Rancher v2.12.10 tag is still present' >&2
  exit 1
fi
grep -q 'platform-webhook-receiver' "$ROOT/scripts/start-webhook-receiver.sh" || { echo 'Containerized webhook receiver integration missing' >&2; exit 1; }
[[ -f "$ROOT/services/platform-webhook-receiver/Dockerfile" ]] || { echo 'Containerized webhook receiver Dockerfile missing' >&2; exit 1; }
printf '  Kubernetes Ops + Rancher integration invariants: PASS\n'

grep -q 'telco-subscriber-service' "$ROOT/platform/components/telco.yaml" || exit 1
grep -q 'telco-network-service' "$ROOT/platform/components/telco.yaml" || exit 1
grep -q 'telco-bss-facade' "$ROOT/platform/components/telco.yaml" || exit 1
grep -q 'telco-mcp' "$ROOT/platform/components/telco.yaml" || exit 1
printf '  OpenChoreo-native telecom adaptation: PASS\n'

if grep -RniIE 'banking technology fair|banking fair|\bfair\b|bank-demo|bank-valkey|bank_demo_|bank-customer-mcp|bank-risk-mcp|bank-compliance-mcp' "$ROOT" --exclude-dir=runtime --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.work --exclude-dir=node_modules --exclude='*.pyc' --exclude=self-test.sh >/tmp/platform-demo-old-brand.$$ 2>/dev/null; then
  cat /tmp/platform-demo-old-brand.$$ >&2; rm -f /tmp/platform-demo-old-brand.$$; echo 'Legacy fair branding remains in the repository' >&2; exit 1
fi
rm -f /tmp/platform-demo-old-brand.$$ 2>/dev/null || true
if grep -RniIE '/Users/[^/]+|/mnt/data/' "$ROOT" --exclude-dir=runtime --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.work --exclude-dir=node_modules --exclude='*.pyc' --exclude=self-test.sh >/tmp/platform-demo-paths.$$ 2>/dev/null; then
  cat /tmp/platform-demo-paths.$$ >&2; rm -f /tmp/platform-demo-paths.$$; echo 'Machine-specific paths remain in the repository' >&2; exit 1
fi
rm -f /tmp/platform-demo-paths.$$ 2>/dev/null || true
printf '  shareable branding/path invariants: PASS\n'
# Fresh-clone OpenChoreo installer invariants.
grep -q -- '--user openchoreo' "$ROOT/scripts/install-openchoreo.sh" || {
  echo "Quick Start installer must run as the non-root openchoreo user"
  exit 1
}

grep -q -- '--group-add "$DOCKER_SOCKET_GID"' "$ROOT/scripts/install-openchoreo.sh" || {
  echo "Quick Start installer does not propagate Docker socket group access"
  exit 1
}

grep -q 'DOCKER_SOCKET_GID=' "$ROOT/scripts/install-openchoreo.sh" || {
  echo "Quick Start installer does not dynamically detect the Docker socket GID"
  exit 1
}

grep -q -- '--kubeconfig-merge-default' "$ROOT/scripts/install-openchoreo.sh" || {
  echo "Quick Start installer does not refresh the host kubeconfig"
  exit 1
}

grep -q -- '--kubeconfig-switch-context' "$ROOT/scripts/install-openchoreo.sh" || {
  echo "Quick Start installer does not switch to the recovered k3d context"
  exit 1
}

grep -q -- '--update' "$ROOT/scripts/install-openchoreo.sh" || {
  echo "Quick Start installer does not refresh stale kubeconfig entries"
  exit 1
}

# Platform Artifacts UI integration invariants
for f in "$ROOT"/extensions/platform-artifacts-ui/scripts/*.sh; do bash -n "$f"; done
python3 -c 'import ast,pathlib,sys; [ast.parse(p.read_text(), filename=str(p)) for p in pathlib.Path(sys.argv[1]).glob("*.py")]' "$ROOT/extensions/platform-artifacts-ui/scripts"
python3 "$ROOT/extensions/platform-artifacts-ui/scripts/patch-custom-artifact-metadata.py" "$ROOT" --check
[[ -x "$ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh" ]] || { echo 'Platform Artifacts ensure script missing' >&2; exit 1; }
grep -q 'ensure-platform-artifacts-ui.sh' "$ROOT/scripts/bootstrap-all.sh" || { echo 'bootstrap is missing Platform Artifacts UI ensure hook' >&2; exit 1; }
grep -q 'verify-platform-artifacts-ui.sh' "$ROOT/scripts/verify-clean-room.sh" || { echo 'clean-room verifier is missing Platform Artifacts UI verification' >&2; exit 1; }
grep -q 'OPENCHOREO_BACKSTAGE_REF:-v1.2.2' "$ROOT/extensions/platform-artifacts-ui/scripts/build-platform-artifacts-ui.sh" || { echo 'Platform Artifacts build is not pinned to OpenChoreo Backstage v1.2.2' >&2; exit 1; }
grep -q 'patch-openchoreo-dockerfile.py' "$ROOT/extensions/platform-artifacts-ui/scripts/build-platform-artifacts-ui.sh" || { echo 'Platform Artifacts build is missing architecture patching' >&2; exit 1; }
if grep -q -- '--platform linux/amd64' "$ROOT/extensions/platform-artifacts-ui/scripts/build-platform-artifacts-ui.sh"; then echo 'Platform Artifacts build still hard-codes linux/amd64' >&2; exit 1; fi
printf '  architecture-native Platform Artifacts UI integration: PASS\n'

# Deterministic containerd image-presence regression guard
for f in "$ROOT/scripts/build-images.sh" "$ROOT/scripts/ensure-app-images.sh"; do
  if grep -Eq 'ctr -n k8s\.io images ls -q.*[|].*grep .*-[A-Za-z]*q' "$f"; then
    echo "$f contains a pipefail-unsafe ctr|grep -q image-presence check" >&2
    exit 1
  fi
  grep -q 'images="$(docker exec "$server_node" ctr -n k8s.io images ls -q' "$f" || {
    echo "$f does not capture the complete containerd image list before matching" >&2
    exit 1
  }
done
grep -q 'ensure-platform-artifacts-ui.sh' "$ROOT/scripts/bootstrap-all.sh" || {
  echo 'bootstrap is missing automatic Platform Artifacts UI installation' >&2
  exit 1
}
printf '  deterministic containerd image verification + portal bootstrap: PASS\n'

printf '\n==> Static repository self-test PASSED\n'
