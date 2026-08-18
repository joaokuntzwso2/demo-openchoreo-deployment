#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need docker; need k3d; need kubectl
ensure_demo_context

services=(accounts-service payments-service fraud-service compliance-service financial-bff mcp-customer mcp-risk mcp-compliance financial-agent platform-portal telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal k8s-ops-console)
server_node="k3d-${CLUSTER}-server-0"

docker inspect "$server_node" >/dev/null 2>&1 || die "Cannot find k3d server node $server_node"
docker buildx version >/dev/null 2>&1 || die "Docker Buildx is required. Update Docker/Colima so 'docker buildx version' works."

node_arch="$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}' 2>/dev/null || true)"
case "$node_arch" in
  arm64) platform="linux/arm64" ;;
  amd64|x86_64) platform="linux/amd64" ;;
  *) die "Unsupported or unknown k3d node architecture: ${node_arch:-<empty>}" ;;
esac

check_node_disk(){
  local vals free_kb used_pct free_gib
  vals="$(docker exec "$server_node" sh -c 'df -Pk /var/lib/rancher/k3s/agent/containerd 2>/dev/null | awk '\''NR==2 {gsub(/%/,"",$5); print $4, $5}'\''' 2>/dev/null || true)"
  [[ -n "$vals" ]] || return 0
  free_kb="${vals%% *}"; used_pct="${vals##* }"
  if [[ "$free_kb" =~ ^[0-9]+$ ]]; then
    free_gib="$(python3 - "$free_kb" <<'PY'
import sys
print(f"{int(sys.argv[1])/1024/1024:.1f}")
PY
)"
  else
    free_gib="unknown"
  fi
  printf '  k3d node image filesystem: %s%% used / %s GiB free\n' "$used_pct" "$free_gib"
  if [[ "$used_pct" =~ ^[0-9]+$ ]] && (( used_pct >= 85 )); then
    docker system df >&2 || true
    die "k3d node image filesystem is ${used_pct}% full. Free Docker/Colima disk space before building; otherwise kubelet image GC can delete freshly imported demo images."
  fi
}

image_present(){
  local svc="$1" expected images
  expected="docker.io/platform-demo/${svc}:1.0.0"

  # Avoid ctr|grep -q under pipefail: grep may exit early after a match,
  # ctr receives SIGPIPE, and the pipeline becomes a false negative.
  images="$(docker exec "$server_node" ctr -n k8s.io images ls -q 2>/dev/null)" || return 1
  grep -Fx "$expected" <<<"$images" >/dev/null
}

import_one(){
  local svc="$1" image="platform-demo/${svc}:1.0.0" attempt tarfile remote_tar

  # k3d can report a successful bulk import while an OCI-index/attestation-backed
  # image is missing from containerd. We therefore import and verify one image at a
  # time, then use a direct containerd tar import as a deterministic fallback.
  for attempt in 1 2; do
    printf '  importing %-22s via k3d (attempt %s/2)\n' "$svc" "$attempt"
    k3d image import -c "$CLUSTER" "$image" >/dev/null 2>&1 || true
    image_present "$svc" && return 0
  done

  warn "k3d did not retain $image; using direct containerd import fallback"
  mkdir -p "$ROOT/runtime/image-import"
  tarfile="$ROOT/runtime/image-import/${svc}.tar"
  remote_tar="/tmp/platform-demo-${svc}.tar"
  rm -f "$tarfile"
  docker image save -o "$tarfile" "$image"
  docker cp "$tarfile" "$server_node:$remote_tar" >/dev/null
  docker exec "$server_node" ctr -n k8s.io images import "$remote_tar" >/dev/null
  docker exec "$server_node" rm -f "$remote_tar" >/dev/null 2>&1 || true
  rm -f "$tarfile"

  # Kubelet normalizes platform-demo/... to docker.io/platform-demo/.... If ctr imported a
  # short repository name, add the canonical tag explicitly before verification.
  if ! image_present "$svc"; then
    candidate="$(docker exec "$server_node" ctr -n k8s.io images ls -q 2>/dev/null \
      | grep -E "(^|/)platform-demo/${svc}:1\.0\.0$" | head -n 1 || true)"
    if [[ -n "$candidate" ]]; then
      docker exec "$server_node" ctr -n k8s.io images tag "$candidate" "docker.io/platform-demo/${svc}:1.0.0" >/dev/null 2>&1 || true
    fi
  fi
  image_present "$svc" || die "Image docker.io/platform-demo/${svc}:1.0.0 is still missing from $server_node after direct containerd import"
}

check_node_disk
log "Building 19 deterministic single-platform platform application images for $platform"

# Docker's containerd image store can emit provenance/attestation manifest lists even
# for local builds. Disable default attestations and export one concrete platform so
# k3d/containerd receives a simple image manifest.
export BUILDX_NO_DEFAULT_ATTESTATIONS=1
build_help="$(docker buildx build --help 2>/dev/null || true)"
grep -q -- '--provenance' <<<"$build_help" \
  || die "Docker Buildx is too old: --provenance is unavailable. Update Docker/Colima before running this demo."
for svc in "${services[@]}"; do
  image="platform-demo/${svc}:1.0.0"
  printf '\n  building %s\n' "$image"
  docker image rm -f "$image" >/dev/null 2>&1 || true
  args=(buildx build --load --platform "$platform" --provenance=false)
  if [[ "${PLATFORM_DEMO_NO_CACHE:-0}" == "1" ]]; then
    args+=(--no-cache --pull)
  fi
  if grep -q -- '--sbom' <<<"$build_help"; then
    args+=(--sbom=false)
  fi
  docker "${args[@]}" -t "$image" -f "$ROOT/services/$svc/Dockerfile" "$ROOT"

  built_arch="$(docker image inspect "$image" --format '{{.Architecture}}' 2>/dev/null || true)"
  case "$platform:$built_arch" in
    linux/arm64:arm64|linux/amd64:amd64) ;;
    *) die "Built $image architecture '$built_arch' does not match k3d node platform '$platform'" ;;
  esac

done

log "Importing and verifying each platform application image in k3d containerd"
for svc in "${services[@]}"; do
  import_one "$svc"
done

log "Verified all 19 platform-demo images inside $server_node"
docker exec "$server_node" ctr -n k8s.io images ls -q 2>/dev/null | grep 'platform-demo/' | sort
check_node_disk
