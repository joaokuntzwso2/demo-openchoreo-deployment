#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

[[ -f demo.sh && -f scripts/lib.sh && -f scripts/bootstrap-all.sh ]] || {
  echo "ERROR: run this from the demo-openchoreo-deployment repository root." >&2
  exit 1
}

BACKUP="/tmp/demo-openchoreo-hardening-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

for f in demo.sh .showcase.env.example scripts/bootstrap-all.sh scripts/preflight.sh scripts/reset-from-scratch.sh scripts/rancher.sh scripts/self-test.sh scripts/showcase-readiness.sh scripts/status.sh; do
  [[ -f "$f" ]] || continue
  mkdir -p "$BACKUP/$(dirname "$f")"
  cp -a "$f" "$BACKUP/$f"
done

cat > scripts/prepare-host.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

[[ "$(uname -s)" == "Darwin" ]] || exit 0
command -v colima >/dev/null 2>&1 || exit 0
colima status >/dev/null 2>&1 || exit 0

log "Preparing Colima inotify limits"
colima ssh -- sudo sysctl -w fs.inotify.max_user_instances=2048 >/dev/null
colima ssh -- sudo sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null
colima ssh -- sudo sysctl -w fs.inotify.max_queued_events=32768 >/dev/null

instances="$(colima ssh -- sysctl -n fs.inotify.max_user_instances | tr -d '\r')"
watches="$(colima ssh -- sysctl -n fs.inotify.max_user_watches | tr -d '\r')"
queued="$(colima ssh -- sysctl -n fs.inotify.max_queued_events | tr -d '\r')"

[[ "$instances" -ge 2048 ]] || die "max_user_instances=$instances"
[[ "$watches" -ge 1048576 ]] || die "max_user_watches=$watches"
[[ "$queued" -ge 32768 ]] || die "max_queued_events=$queued"
EOF

cat > scripts/reconcile-openchoreo-auth.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

CTX="$(demo_context)"
CP_NS="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
THUNDER_NS="${OPENCHOREO_THUNDER_NAMESPACE:-thunder}"
BACKSTAGE="${OPENCHOREO_BACKSTAGE_DEPLOYMENT:-backstage}"

start=$SECONDS
until kubectl --context "$CTX" -n "$CP_NS" get deployment "$BACKSTAGE" >/dev/null 2>&1; do
  (( SECONDS-start < 300 )) || die "Backstage deployment did not appear"
  sleep 3
done

start=$SECONDS
until kubectl --context "$CTX" -n "$THUNDER_NS" get svc -l app.kubernetes.io/name=thunder -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; do
  (( SECONDS-start < 300 )) || die "Thunder service did not appear"
  sleep 3
done

svc="$(kubectl --context "$CTX" -n "$THUNDER_NS" get svc -l app.kubernetes.io/name=thunder -o jsonpath='{.items[0].metadata.name}')"
port="$(kubectl --context "$CTX" -n "$THUNDER_NS" get svc "$svc" -o jsonpath='{.spec.ports[0].port}')"
url="http://${svc}.${THUNDER_NS}.svc.cluster.local:${port}/oauth2/token"

log "Reconciling Backstage Thunder token URL"
printf '  %s\n' "$url"

current="$(kubectl --context "$CTX" -n "$CP_NS" get deployment "$BACKSTAGE" -o jsonpath='{range .spec.template.spec.containers[0].env[?(@.name=="OPENCHOREO_AUTH_TOKEN_URL")]}{.value}{end}' 2>/dev/null || true)"
if [[ "$current" != "$url" ]]; then
  kubectl --context "$CTX" -n "$CP_NS" set env deployment/"$BACKSTAGE" OPENCHOREO_AUTH_TOKEN_URL="$url" >/dev/null
fi

kubectl --context "$CTX" -n "$CP_NS" rollout status deployment/"$BACKSTAGE" --timeout=300s

status="$(
kubectl --context "$CTX" -n "$CP_NS" exec deployment/"$BACKSTAGE" -- node -e "
fetch('${url}',{
 method:'POST',
 headers:{'content-type':'application/x-www-form-urlencoded'},
 body:'grant_type=client_credentials&client_id=openchoreo-backstage-client&client_secret=backstage-portal-secret'
}).then(r=>{console.log(r.status);process.exit(r.status===200?0:1)}).catch(()=>process.exit(1))
" 2>/dev/null | tail -1
)"

[[ "$status" == "200" ]] || die "Backstage cannot exchange a token through $url"
log "Backstage -> Thunder token exchange: PASS"
EOF

cat > scripts/wait-openchoreo-catalog.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

CTX="$(demo_context)"
CP_NS="${OPENCHOREO_CONTROL_PLANE_NAMESPACE:-openchoreo-control-plane}"
BACKSTAGE="${OPENCHOREO_BACKSTAGE_DEPLOYMENT:-backstage}"
TIMEOUT="${OPENCHOREO_CATALOG_TIMEOUT:-360}"

log "Waiting for OpenChoreo catalog convergence"

start=$SECONDS
while (( SECONDS-start < TIMEOUT )); do
  if kubectl --context "$CTX" -n "$CP_NS" logs deployment/"$BACKSTAGE" --since=15m 2>/dev/null \
    | grep -Eq 'Successfully processed [0-9]+ entities \(2 domains, 11 systems, 19 components,'; then
    sleep "${OPENCHOREO_CATALOG_SETTLE_SECONDS:-20}"
    log "OpenChoreo catalog convergence: PASS"
    exit 0
  fi
  sleep 5
done

kubectl --context "$CTX" -n "$CP_NS" logs deployment/"$BACKSTAGE" --since=15m 2>/dev/null | tail -120 >&2 || true
die "Expected Backstage catalog state did not converge within ${TIMEOUT}s"
EOF

cat > scripts/rancher.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

RANCHER_CLUSTER="${RANCHER_CLUSTER:-rancher-mgmt}"
RANCHER_CONTEXT="${RANCHER_CONTEXT:-k3d-${RANCHER_CLUSTER}}"
RANCHER_K3S_IMAGE="${RANCHER_K3S_IMAGE:-rancher/k3s:v1.35.5-k3s1}"
RANCHER_CHART_VERSION="${RANCHER_CHART_VERSION:-2.14.3}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.21.1}"
RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-rancher.localhost}"
RANCHER_HTTPS_PORT="${RANCHER_HTTPS_PORT:-8444}"
RANCHER_API_PORT="${RANCHER_API_PORT:-6551}"
RANCHER_URL="https://${RANCHER_HOSTNAME}:${RANCHER_HTTPS_PORT}"
RANCHER_PASSWORD_FILE="${RANCHER_PASSWORD_FILE:-$ROOT/runtime/rancher-bootstrap-password}"

exists() {
  k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$RANCHER_CLUSTER"
}

restore_context() {
  ctx="$(demo_context)"
  kubectl config get-contexts -o name 2>/dev/null | grep -Fxq "$ctx" || return 0
  kubectl config use-context "$ctx" >/dev/null 2>&1 || true
}

password() {
  mkdir -p "$(dirname "$RANCHER_PASSWORD_FILE")"
  if [[ -n "${RANCHER_BOOTSTRAP_PASSWORD:-}" ]]; then
    RANCHER_PASSWORD="$RANCHER_BOOTSTRAP_PASSWORD"
  else
    if [[ ! -s "$RANCHER_PASSWORD_FILE" ]]; then
      umask 077
      python3 -c 'import secrets; print(secrets.token_urlsafe(24))' > "$RANCHER_PASSWORD_FILE"
    fi
    RANCHER_PASSWORD="$(cat "$RANCHER_PASSWORD_FILE")"
  fi
}

create_cluster() {
  exists && return 0
  "$ROOT/scripts/prepare-host.sh"
  log "Creating Rancher management k3d cluster"
  k3d cluster create "$RANCHER_CLUSTER" \
    --image "$RANCHER_K3S_IMAGE" \
    --servers 1 \
    --agents 0 \
    --api-port "$RANCHER_API_PORT" \
    -p "${RANCHER_HTTPS_PORT}:443@loadbalancer" \
    --wait \
    --timeout 180s
  k3d kubeconfig merge "$RANCHER_CLUSTER" --kubeconfig-merge-default --update >/dev/null
  kubectl --context "$RANCHER_CONTEXT" wait node --all --for=condition=Ready --timeout=180s
}

install_cert_manager() {
  helm repo add jetstack https://charts.jetstack.io --force-update >/dev/null
  helm repo update >/dev/null
  log "Installing cert-manager $CERT_MANAGER_VERSION"
  helm upgrade --install cert-manager jetstack/cert-manager \
    --kube-context "$RANCHER_CONTEXT" \
    --namespace cert-manager \
    --create-namespace \
    --version "$CERT_MANAGER_VERSION" \
    --set crds.enabled=true \
    --wait \
    --timeout 10m
}

install_rancher() {
  password
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest --force-update >/dev/null
  helm repo update >/dev/null
  helm show chart rancher-latest/rancher --version "$RANCHER_CHART_VERSION" >/dev/null \
    || die "Rancher chart $RANCHER_CHART_VERSION is unavailable"
  log "Installing Rancher $RANCHER_CHART_VERSION"
  helm upgrade --install rancher rancher-latest/rancher \
    --kube-context "$RANCHER_CONTEXT" \
    --namespace cattle-system \
    --create-namespace \
    --version "$RANCHER_CHART_VERSION" \
    --set hostname="$RANCHER_HOSTNAME" \
    --set replicas=1 \
    --set bootstrapPassword="$RANCHER_PASSWORD" \
    --wait \
    --timeout 15m
}

verify() {
  exists || die "Rancher cluster does not exist"
  kubectl --context "$RANCHER_CONTEXT" -n cattle-system rollout status deployment/rancher --timeout=300s
  start=$SECONDS
  while (( SECONDS-start < 300 )); do
    [[ "$(curl -ksS --max-time 5 "$RANCHER_URL/readyz" 2>/dev/null || true)" == "ok" ]] && break
    sleep 5
  done
  [[ "$(curl -ksS --max-time 5 "$RANCHER_URL/readyz" 2>/dev/null || true)" == "ok" ]] || die "Rancher /readyz failed"
  if kubectl --context "$RANCHER_CONTEXT" get apiservice v1.ext.cattle.io >/dev/null 2>&1; then
    available="$(kubectl --context "$RANCHER_CONTEXT" get apiservice v1.ext.cattle.io -o jsonpath='{range .status.conditions[?(@.type=="Available")]}{.status}{end}')"
    [[ "$available" == "True" ]] || die "v1.ext.cattle.io is not Available=True"
  fi
  log "Rancher management UI: PASS"
  printf '  %s\n' "$RANCHER_URL"
}

up() {
  create_cluster
  install_cert_manager
  install_rancher
  verify
  restore_context
}

case "${1:-up}" in
  up) up ;;
  start)
    if exists; then k3d cluster start "$RANCHER_CLUSTER" >/dev/null; verify; restore_context; else up; fi
    ;;
  stop)
    exists && k3d cluster stop "$RANCHER_CLUSTER" >/dev/null || true
    restore_context
    ;;
  destroy)
    exists && k3d cluster delete "$RANCHER_CLUSTER" >/dev/null || true
    restore_context
    ;;
  verify)
    verify
    restore_context
    ;;
  status)
    if exists; then
      k3d cluster list | awk -v c="$RANCHER_CLUSTER" 'NR==1 || $1==c'
      printf 'URL: %s\n' "$RANCHER_URL"
    else
      echo "Rancher: disabled/not installed (optional)"
    fi
    ;;
  register)
    warn "OpenChoreo downstream import is not yet part of strict fresh-clone acceptance for the new Helm-based Rancher architecture."
    restore_context
    ;;
  *)
    echo "Usage: $0 [up|start|stop|destroy|verify|status|register]" >&2
    exit 2
    ;;
esac
EOF

cat > .showcase.env.example <<'EOF'
ENABLE_RANCHER='0'

# ENABLE_RANCHER='1'
# RANCHER_K3S_IMAGE='rancher/k3s:v1.35.5-k3s1'
# RANCHER_CHART_VERSION='2.14.3'
# CERT_MANAGER_VERSION='v1.21.1'
# RANCHER_HOSTNAME='rancher.localhost'
# RANCHER_HTTPS_PORT='8444'

ENABLE_PLATFORM_ARTIFACTS_UI=1
PLATFORM_ARTIFACTS_ROLLOUT_TIMEOUT=10m
EOF

cat > scripts/showcase-readiness.sh <<'EOF'
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
EOF

python3 - <<'PY'
from pathlib import Path
import re

def rd(p): return Path(p).read_text()
def wr(p,s): Path(p).write_text(s)

p="scripts/bootstrap-all.sh"
s=rd(p)
if '"$ROOT/scripts/prepare-host.sh"' not in s:
    s=s.replace('"$ROOT/scripts/preflight.sh"\n"$ROOT/scripts/install-openchoreo.sh"',
                '"$ROOT/scripts/preflight.sh"\n"$ROOT/scripts/prepare-host.sh"\n"$ROOT/scripts/install-openchoreo.sh"')
if '"$ROOT/scripts/reconcile-openchoreo-auth.sh"' not in s:
    s=s.replace('"$ROOT/scripts/install-openchoreo.sh"\nensure_demo_context',
                '"$ROOT/scripts/install-openchoreo.sh"\n"$ROOT/scripts/reconcile-openchoreo-auth.sh"\nensure_demo_context')
s=re.sub(r'if \[\[ "\$\{ENABLE_RANCHER:-[01]\}" == "1" \]\]; then.*?\nfi\nlog "Loading deterministic financial scenarios"',
         'if [[ "${ENABLE_RANCHER:-0}" == "1" ]]; then\n  log "Starting optional Rancher management cluster"\n  "$ROOT/scripts/rancher.sh" up\nfi\nlog "Loading deterministic financial scenarios"',
         s, count=1, flags=re.S)
if '"$ROOT/scripts/wait-openchoreo-catalog.sh"' not in s:
    s=s.replace('"$ROOT/scripts/bootstrap-telco-data.sh"\n"$ROOT/scripts/status.sh"',
                '"$ROOT/scripts/bootstrap-telco-data.sh"\n"$ROOT/scripts/wait-openchoreo-catalog.sh"\n"$ROOT/scripts/status.sh"')
s=s.replace("Rancher: https://localhost:8444","Rancher: https://rancher.localhost:8444")
wr(p,s)

p="scripts/preflight.sh"
wr(p,rd(p).replace('${ENABLE_RANCHER:-1}','${ENABLE_RANCHER:-0}'))

p="demo.sh"
s=rd(p).replace('    "$ROOT/scripts/rancher.sh" register || true\n','')
wr(p,s)

p="scripts/reset-from-scratch.sh"
s=rd(p).replace("Rancher\n# container/volume","Rancher\n# management k3d cluster")
wr(p,s)

p="scripts/status.sh"
s=rd(p).replace("https://localhost:8444","https://rancher.localhost:8444")
wr(p,s)

p="scripts/self-test.sh"
s=rd(p)
a=s.find("grep -q 'rancher/rancher@sha256:")
b=s.find("printf '  Kubernetes Ops + Rancher integration invariants: PASS\\n'",a)
if a!=-1 and b!=-1:
    b += len("printf '  Kubernetes Ops + Rancher integration invariants: PASS\\n'")
    new = "\n".join([
      "grep -q 'RANCHER_CLUSTER=\"${RANCHER_CLUSTER:-rancher-mgmt}\"' \"$ROOT/scripts/rancher.sh\" || exit 1",
      "grep -q 'RANCHER_K3S_IMAGE=\"${RANCHER_K3S_IMAGE:-rancher/k3s:v1.35.5-k3s1}\"' \"$ROOT/scripts/rancher.sh\" || exit 1",
      "grep -q 'RANCHER_CHART_VERSION=\"${RANCHER_CHART_VERSION:-2.14.3}\"' \"$ROOT/scripts/rancher.sh\" || exit 1",
      "grep -q 'rancher-latest/rancher' \"$ROOT/scripts/rancher.sh\" || exit 1",
      "if grep -q 'docker run .*rancher/rancher' \"$ROOT/scripts/rancher.sh\"; then echo 'Old Docker Rancher implementation remains' >&2; exit 1; fi",
      "grep -q 'platform-webhook-receiver' \"$ROOT/scripts/start-webhook-receiver.sh\" || exit 1",
      "[[ -f \"$ROOT/services/platform-webhook-receiver/Dockerfile\" ]] || exit 1",
      "printf '  Kubernetes Ops + Helm-based Rancher integration invariants: PASS\\n'"
    ])
    s=s[:a]+new+s[b:]

if "fresh-clone host/auth/catalog hardening invariants" not in s:
    marker="# Platform Artifacts UI integration invariants"
    checks="\n".join([
      "# Fresh-clone host/auth/catalog hardening invariants",
      "[[ -x \"$ROOT/scripts/prepare-host.sh\" ]] || exit 1",
      "grep -q 'fs.inotify.max_user_instances=2048' \"$ROOT/scripts/prepare-host.sh\" || exit 1",
      "grep -q 'svc.cluster.local' \"$ROOT/scripts/reconcile-openchoreo-auth.sh\" || exit 1",
      "grep -q 'reconcile-openchoreo-auth.sh' \"$ROOT/scripts/bootstrap-all.sh\" || exit 1",
      "grep -q 'wait-openchoreo-catalog.sh' \"$ROOT/scripts/bootstrap-all.sh\" || exit 1",
      "grep -q 'ENABLE_RANCHER:-0' \"$ROOT/scripts/bootstrap-all.sh\" || exit 1",
      "printf '  fresh-clone host/auth/catalog hardening invariants: PASS\\n'",
      ""
    ])
    if marker in s:
        s=s.replace(marker,checks+marker)
wr(p,s)
PY

chmod +x scripts/prepare-host.sh scripts/reconcile-openchoreo-auth.sh scripts/wait-openchoreo-catalog.sh scripts/rancher.sh scripts/showcase-readiness.sh

echo
echo "==> Shell syntax"
bash -n demo.sh
for f in scripts/*.sh; do bash -n "$f"; done

echo
echo "==> Repository self-test"
./scripts/self-test.sh

echo
echo "==> Diff check"
git diff --check

echo
git status --short
echo
echo "Backup: $BACKUP"
echo
echo "Run next:"
echo "  git diff"
echo "  ./demo.sh reset"
echo "  ./demo.sh verify"
echo "  ./demo.sh readiness"
