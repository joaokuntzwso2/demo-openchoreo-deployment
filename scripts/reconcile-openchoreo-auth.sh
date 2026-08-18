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
