#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

log "Checking workstation prerequisites for the complete OpenChoreo platform application"
"$ROOT/scripts/self-test.sh"
if [[ "${SKIP_LOCAL_VALIDATION:-0}" != "1" ]]; then
  if command -v node >/dev/null 2>&1; then "$ROOT/scripts/validate-local-services.sh"; else warn "Host Node.js is not installed; skipping the optional source-level integration test. All runtime services are containerized and the clean-room verifier still runs."; fi
fi
missing=0
for cmd in docker k3d kubectl helm curl python3; do
  if command -v "$cmd" >/dev/null 2>&1; then printf '  %-10s %s\n' "$cmd" "$(command -v "$cmd")"; else printf '  %-10s MISSING\n' "$cmd" >&2; missing=1; fi
done
[[ "$missing" -eq 0 ]] || die "Install the missing prerequisites before bootstrap. See README.md."
docker info >/dev/null 2>&1 || die "Docker is installed but the daemon is not reachable. Start Docker Desktop or Colima first."
docker buildx version >/dev/null 2>&1 || die "Docker Buildx is required."

printf '\nVersions:\n'; docker --version; k3d --version; kubectl version --client; helm version --short; command -v node >/dev/null 2>&1 && node --version || echo 'node: optional / not installed'; docker buildx version | head -n 1
read -r cpus mem_bytes < <(docker info --format '{{.NCPU}} {{.MemTotal}}' 2>/dev/null || echo '0 0')
if [[ "$cpus" =~ ^[0-9]+$ ]] && (( cpus < 4 )); then die "Docker reports $cpus CPUs. Allocate at least 4 CPUs; 6 are recommended."; fi
min_mem_bytes=10737418240
if [[ "${ENABLE_RANCHER:-1}" == "1" ]]; then min_mem_bytes=12884901888; fi
if [[ "$mem_bytes" =~ ^[0-9]+$ ]] && (( mem_bytes > 0 && mem_bytes < min_mem_bytes )); then
  mem_gib="$(python3 - "$mem_bytes" <<'PY'
import sys
print(round(int(sys.argv[1])/1024/1024/1024,1))
PY
)"
  die "Docker reports ${mem_gib} GiB RAM. This package runs OpenChoreo, observability, 19 app workloads and Rancher; allocate at least 12 GiB with Rancher enabled (16 GiB recommended), or set ENABLE_RANCHER=0 for a lighter OpenChoreo-only run."
fi
if [[ "$mem_bytes" =~ ^[0-9]+$ ]] && (( mem_bytes >= min_mem_bytes && mem_bytes < 17179869184 )); then warn "Docker has less than the recommended 16 GiB RAM. The complete stack can run, but Rancher plus observability and 19 application workloads may be tight."; fi
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then printf '\nApple Silicon detected. Recommended Colima configuration:\n  colima start --vm-type=vz --vz-rosetta --cpu 6 --memory 16\n'; fi

log "Checking Docker VM image-filesystem headroom"
disk="$(docker run --rm --pull=missing alpine:3.22 sh -c 'df -Pk / | awk '\''NR==2 {gsub(/%/,"",$5); print $4, $5}'\''' 2>/dev/null || true)"
if [[ -n "$disk" ]]; then
  free_kb="${disk%% *}"; used_pct="${disk##* }"; free_gib="$(python3 - "$free_kb" <<'PY'
import sys
print(f"{int(sys.argv[1])/1024/1024:.1f}")
PY
)"
  printf '  Docker VM filesystem: %s%% used / %s GiB free\n' "$used_pct" "$free_gib"
  if [[ "$used_pct" =~ ^[0-9]+$ ]] && (( used_pct >= 85 )); then docker system df >&2 || true; die "Docker VM filesystem is ${used_pct}% full."; fi
  if [[ "$free_kb" =~ ^[0-9]+$ ]] && (( free_kb < 26214400 )); then docker system df >&2 || true; die "Docker VM has less than 25 GiB free. Free/increase disk before this full-stack bootstrap."; fi
else
  warn "Could not measure Docker VM free space; the image importer will check the k3d node later."
fi

if ! k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER"; then
  log "Checking host ports for a fresh OpenChoreo installation"
  PORTS="8080 10081 10082 11080 18081 19080"
  if [[ "${ENABLE_RANCHER:-1}" == "1" ]] && ! docker ps -a --format '{{.Names}}' | grep -Fxq platform-rancher; then PORTS="$PORTS 8444"; fi
  python3 - $PORTS <<'PY'
import socket,sys
ports=[int(x) for x in sys.argv[1:]]; busy=[]
for p in ports:
 s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
 try:s.bind(('127.0.0.1',p))
 except OSError:busy.append(p)
 finally:s.close()
if busy: raise SystemExit('Ports already in use: '+', '.join(map(str,busy)))
print('  ports available: '+', '.join(map(str,ports)))
PY
fi
log "Preflight passed"
