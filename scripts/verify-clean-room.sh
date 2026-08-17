#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl; need curl; need python3; need docker
ensure_demo_context

services=(accounts-service payments-service fraud-service compliance-service financial-bff mcp-customer mcp-risk mcp-compliance financial-agent platform-portal telco-subscriber-service telco-network-service telco-commercial-service telco-policy-service telco-legacy-billing telco-bss-facade telco-mcp telco-portal k8s-ops-console)
server_node="k3d-${CLUSTER}-server-0"
projects=(experience payments risk customer compliance telco-core telco-network telco-commercial telco-experience platform-ops)

log "Verifying 30/30 platform ProjectReleaseBindings"
state="$(kubectl get projectreleasebinding -n "$NS" -o json | python3 -c '
import json,sys
x=json.load(sys.stdin)
ps=["experience","payments","risk","customer","compliance","telco-core","telco-network","telco-commercial","telco-experience","platform-ops"]
want={f"{p}-{e}" for p in ps for e in ["development","staging","production"]}
items=[i for i in x.get("items",[]) if i.get("metadata",{}).get("name") in want]
ready=[i for i in items if any(c.get("type")=="Ready" and c.get("status")=="True" for c in i.get("status",{}).get("conditions",[]) or [])]
print(len(items),len(ready))
')"
[[ "$state" == "30 30" ]] || die "ProjectReleaseBindings not 30/30 Ready: $state"

log "Verifying all 19 application images in the actual k3d node"
docker inspect "$server_node" >/dev/null 2>&1 || die "Missing k3d server node $server_node"
containerd_images="$(
  docker exec "$server_node"     ctr -n k8s.io images ls -q 2>/dev/null
)" || die "Unable to query images from k3d containerd"

missing=()

for svc in "${services[@]}"; do
  expected="docker.io/platform-demo/${svc}:1.0.0"

  if ! grep -Fxq "$expected" <<<"$containerd_images"; then
    missing+=("$svc")
  fi
done

((${#missing[@]} == 0)) ||   die "k3d containerd is missing platform-demo images: ${missing[*]}"

log "Verifying exactly 19 platform application Components"
count="$(kubectl get component -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
[[ "$count" == "19" ]] || die "Expected 19 Components, found $count"

log "Verifying all 19 development ReleaseBindings are Ready"
for c in "${services[@]}"; do
  case "$c" in
    mcp-customer)   component="customer-mcp" ;;
    mcp-risk)       component="risk-mcp" ;;
    mcp-compliance) component="compliance-mcp" ;;
    *)              component="$c" ;;
  esac

  wait_ready releasebinding "${component}-development" "$NS" 240
done

log "Verifying managed payment cache"
wait_ready resourcereleasebinding payment-idempotency-cache-development "$NS" 180

log "Verifying all development Deployments and the Valkey StatefulSet"
notready="$(kubectl get deploy -A -o json | python3 -c '
import json,sys
x=json.load(sys.stdin); bad=[]
for d in x.get("items",[]):
 ns=d.get("metadata",{}).get("namespace","")
 if not (ns.startswith("dp-platform-demo-") and "-development-" in ns): continue
 desired=d.get("spec",{}).get("replicas",1); available=d.get("status",{}).get("availableReplicas",0) or 0
 if available < desired: bad.append("{}/{}:{}/{}".format(ns,d["metadata"]["name"],available,desired))
print(" ".join(bad))
')"
[[ -z "$notready" ]] || die "Application Deployments not Ready: $notready"
valkey_ready="$(kubectl get sts -A -o json | python3 -c 'import json,sys;x=json.load(sys.stdin);print(next((s.get("status",{}).get("readyReplicas",0) or 0 for s in x.get("items",[]) if "payment-idempotency-cache" in s.get("metadata",{}).get("name","")),0))')"
[[ "$valkey_ready" == "1" ]] || die "Valkey StatefulSet is not Ready"

wait_url(){ local component="$1" u="" start=$SECONDS; while (( SECONDS-start < 150 )); do u="$(external_url "$component" 2>/dev/null || true)"; [[ -n "$u" ]] && { printf '%s' "$u"; return 0; }; sleep 2; done; return 1; }
log "Resolving external demonstration routes"
PORTAL="$(wait_url platform-portal)" || die "Platform Portal route missing"
FIN="$(wait_url financial-bff)" || die "Financial UI route missing"
AGENT="$(wait_url financial-agent)" || die "Financial Agent route missing"
TELCO="$(wait_url telco-portal)" || die "Telco Portal route missing"
OPS="$(wait_url k8s-ops-console)" || die "Kubernetes Ops route missing"
SUBSCRIBER="$(wait_url telco-subscriber-service)" || die "Subscriber backend route missing"
NETWORK="$(wait_url telco-network-service)" || die "Network backend route missing"
BSS="$(wait_url telco-bss-facade)" || die "BSS facade route missing"

log "Verifying the unified Platform Portal"
curl -fsS --max-time 15 "$PORTAL/" | grep -Eq 'OpenChoreo Financial Services Platform|Platform Application' || die "Platform Portal did not return expected HTML"
curl -fsS --max-time 15 "$PORTAL/api/status" >/tmp/platform-status.json
python3 - <<'PY'
import json
x=json.load(open('/tmp/platform-status.json'))
assert x['total'] >= 8, x
assert x['healthy'] >= 8, x
print(f"Platform Portal dependencies healthy: {x['healthy']}/{x['total']}")
PY

log "Verifying financial transaction orchestration"
curl -fsS --max-time 15 "$FIN/api/overview?customerId=C001" >/tmp/platform-fin-overview.json
curl -fsS --max-time 15 -X POST "$FIN/api/pay" -H 'content-type: application/json' \
  -d "{\"transactionId\":\"TX-VERIFY-$(date +%s)\",\"customerId\":\"C001\",\"amount\":1250,\"currency\":\"BRL\",\"beneficiaryName\":\"Loja Exemplo SA\",\"destinationCountry\":\"BR\",\"deviceId\":\"device-maria-1\",\"channel\":\"WEB\"}" >/tmp/platform-fin-pay.json
python3 - <<'PY'
import json
x=json.load(open('/tmp/platform-fin-pay.json'))
got=(x.get('status'),x.get('fraud',{}).get('decision'),x.get('compliance',{}).get('decision'),x.get('cache',{}).get('status'))
assert got==('ACCEPTED','ALLOW','CLEAR','UP'),got
print('Financial flow:',got)
PY
curl -fsS --max-time 15 "$AGENT/api/mcp-status" >/tmp/platform-agent.json

log "Verifying telecom backends and experience"
curl -fsS --max-time 15 "$SUBSCRIBER/api/subscribers/5511999999999/status" >/tmp/platform-telco-subscriber.json
curl -fsS --max-time 15 "$NETWORK/api/network/summary" >/tmp/platform-telco-network.json
curl -fsS --max-time 15 "$BSS/api/billing/5511999999999" >/tmp/platform-telco-bss.json
curl -fsS --max-time 15 "$TELCO/api/subscriber/5511999999999" >/tmp/platform-telco-portal.json
curl -fsS --max-time 15 -X POST "$TELCO/api/qod" -H 'content-type: application/json' -d '{"subscriberId":"5511999999999","profile":"LOW_LATENCY","durationSeconds":900,"country":"BR"}' >/tmp/platform-telco-qod.json
curl -fsS --max-time 15 -X POST "$TELCO/api/policy" -H 'content-type: application/json' -d '{"partnerId":"partner-alpha","country":"BR","dataResidency":"OUTSIDE_BR","consent":"ACTIVE","action":"LOCATION"}' >/tmp/platform-telco-policy.json
python3 - <<'PY'
import json
s=json.load(open('/tmp/platform-telco-subscriber.json')); q=json.load(open('/tmp/platform-telco-qod.json')); p=json.load(open('/tmp/platform-telco-policy.json')); b=json.load(open('/tmp/platform-telco-bss.json'))
assert s['serviceStatus']=='ACTIVE',s
assert q['status']=='ACTIVE',q
assert p['decision']=='DENY' and 'BR_DATA_RESIDENCY' in p['blockingFindings'],p
assert b['mediation']=='SOAP/XML → REST/JSON',b
print('Telco flow: subscriber ACTIVE / QoD ACTIVE / policy DENY / SOAP→REST OK')
PY

log "Verifying live Kubernetes Operations Console"
curl -fsS --max-time 15 "$OPS/api/summary" >/tmp/platform-k8s-summary.json
python3 - <<'PY'
import json
x=json.load(open('/tmp/platform-k8s-summary.json'))
assert x['components']==19,x
assert x['deployments']>=19,x
assert x['running']>=19,x
print(f"Kubernetes Ops: {x['running']} running pods / {x['deployments']} deployments / {x['components']} OpenChoreo components")
PY

log "Verifying Payments observability release"
kubectl get renderedrelease payments-service-development-observability -n "$NS" >/dev/null

if [[ "${ENABLE_RANCHER:-1}" == "1" ]]; then
  log "Verifying Rancher server and downstream cluster registration"
  if "$ROOT/scripts/rancher.sh" verify; then
    :
  elif [[ "${RANCHER_REQUIRED:-0}" == "1" ]]; then
    die "Rancher was requested as a strict acceptance gate but cluster registration is not Ready"
  else
    warn "Rancher registration is not ready yet; core OpenChoreo application verification passed. Run ./demo.sh rancher to retry, or use RANCHER_REQUIRED=1 for a strict clean-room gate."
  fi
fi

log "CLEAN-ROOM CORE VERIFICATION PASSED"
printf 'Platform Portal: %s\nFinancial UI: %s\nFinancial Agent: %s\nTelco Portal: %s\nKubernetes Ops: %s\nRancher: https://localhost:8444\n' "$PORTAL" "$FIN" "$AGENT" "$TELCO" "$OPS"
