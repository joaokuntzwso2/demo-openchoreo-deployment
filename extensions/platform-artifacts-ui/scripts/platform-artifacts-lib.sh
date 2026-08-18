#!/usr/bin/env bash
set -euo pipefail

pa_normalize_arch() {
  case "${1:-}" in
    arm64|aarch64) printf 'arm64\n' ;;
    amd64|x86_64|x64) printf 'amd64\n' ;;
    *) return 1 ;;
  esac
}

pa_cluster_exists() {
  local cluster="${1:-openchoreo-quick-start}"
  command -v k3d >/dev/null 2>&1 || return 1
  k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "$cluster"
}

pa_target_arch() {
  local cluster="${OPENCHOREO_CLUSTER_NAME:-openchoreo-quick-start}"
  local raw="${PLATFORM_ARTIFACTS_ARCH:-}"

  if [[ -z "$raw" ]] && command -v kubectl >/dev/null 2>&1 && pa_cluster_exists "$cluster"; then
    k3d kubeconfig merge "$cluster" --kubeconfig-switch-context >/dev/null 2>&1 || true
    raw="$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}' 2>/dev/null || true)"
  fi

  if [[ -z "$raw" ]] && command -v docker >/dev/null 2>&1; then
    raw="$(docker info --format '{{.Architecture}}' 2>/dev/null || true)"
  fi

  if ! pa_normalize_arch "$raw"; then
    echo "ERROR: unable to determine supported target architecture from '$raw' (expected arm64 or amd64)" >&2
    return 1
  fi
}

pa_default_image() {
  local arch="${1:?architecture is required}"
  printf '%s\n' "${PLATFORM_ARTIFACTS_IMAGE:-openchoreo-ui-platform-artifacts:local-${arch}}"
}

pa_image_arch() {
  local image="${1:?image is required}"
  docker image inspect "$image" --format '{{.Architecture}}' 2>/dev/null | head -1
}

pa_image_matches_arch() {
  local image="${1:?image is required}" expected="${2:?architecture is required}" actual
  actual="$(pa_image_arch "$image" || true)"
  [[ -n "$actual" ]] && [[ "$(pa_normalize_arch "$actual" 2>/dev/null || true)" == "$expected" ]]
}
