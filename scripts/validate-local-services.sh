#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need node; need curl; need python3
TMP="$(mktemp -d)"; PIDS=()
cleanup(){ for p in "${PIDS[@]:-}"; do kill "$p" >/dev/null 2>&1 || true; done; rm -rf "$TMP"; }
trap cleanup EXIT
start(){ local name="$1" port="$2"; shift 2; PORT="$port" "$@" >"$TMP/$name.log" 2>&1 & PIDS+=("$!"); }
S="$ROOT/services"

start accounts 19301 node "$S/accounts-service/server.js"
start fraud 19302 node "$S/fraud-service/server.js"
start compliance 19303 node "$S/compliance-service/server.js"
PORT=19304 FRAUD_API_URL=http://127.0.0.1:19302 COMPLIANCE_API_URL=http://127.0.0.1:19303 node "$S/payments-service/server.js" >"$TMP/payments.log" 2>&1 & PIDS+=("$!")
PORT=19305 ACCOUNTS_API_URL=http://127.0.0.1:19301 PAYMENTS_API_URL=http://127.0.0.1:19304 FRAUD_API_URL=http://127.0.0.1:19302 COMPLIANCE_API_URL=http://127.0.0.1:19303 node "$S/financial-bff/server.js" >"$TMP/bff.log" 2>&1 & PIDS+=("$!")
PORT=19311 ACCOUNTS_API_URL=http://127.0.0.1:19301 node "$S/mcp-customer/server.js" >"$TMP/customer-mcp.log" 2>&1 & PIDS+=("$!")
PORT=19312 FRAUD_API_URL=http://127.0.0.1:19302 node "$S/mcp-risk/server.js" >"$TMP/risk-mcp.log" 2>&1 & PIDS+=("$!")
PORT=19313 COMPLIANCE_API_URL=http://127.0.0.1:19303 node "$S/mcp-compliance/server.js" >"$TMP/compliance-mcp.log" 2>&1 & PIDS+=("$!")
PORT=19320 CUSTOMER_MCP_URL=http://127.0.0.1:19311/mcp RISK_MCP_URL=http://127.0.0.1:19312/mcp COMPLIANCE_MCP_URL=http://127.0.0.1:19313/mcp CONTROL_MCP_URL=http://127.0.0.1:19998/mcp OBS_MCP_URL=http://127.0.0.1:19999/mcp OPENCHOREO_TOKEN_URL=http://127.0.0.1:19997/oauth2/token node "$S/financial-agent/server.js" >"$TMP/agent.log" 2>&1 & PIDS+=("$!")

start subscriber 19401 node "$S/telco-subscriber-service/server.js"
start network 19402 node "$S/telco-network-service/server.js"
start commercial 19403 node "$S/telco-commercial-service/server.js"
start policy 19404 node "$S/telco-policy-service/server.js"
start legacy 19405 node "$S/telco-legacy-billing/server.js"
PORT=19406 LEGACY_BILLING_URL=http://127.0.0.1:19405 node "$S/telco-bss-facade/server.js" >"$TMP/bss.log" 2>&1 & PIDS+=("$!")
PORT=19407 SUBSCRIBER_URL=http://127.0.0.1:19401 NETWORK_URL=http://127.0.0.1:19402 COMMERCIAL_URL=http://127.0.0.1:19403 POLICY_URL=http://127.0.0.1:19404 BSS_URL=http://127.0.0.1:19406 node "$S/telco-portal/server.js" >"$TMP/telco-portal.log" 2>&1 & PIDS+=("$!")
PORT=19408 SUBSCRIBER_URL=http://127.0.0.1:19401 NETWORK_URL=http://127.0.0.1:19402 COMMERCIAL_URL=http://127.0.0.1:19403 POLICY_URL=http://127.0.0.1:19404 node "$S/telco-mcp/server.js" >"$TMP/telco-mcp.log" 2>&1 & PIDS+=("$!")

# Minimal health endpoint stands in for the in-cluster Kubernetes console during this local source test.
PORT=19409 node -e 'require("http").createServer((q,r)=>{r.setHeader("content-type","application/json");r.end(JSON.stringify({status:"UP",service:"k8s-ops-local-mock"}))}).listen(process.env.PORT,"127.0.0.1")' >"$TMP/opsmock.log" 2>&1 & PIDS+=("$!")
PORT=19410 FINANCIAL_BFF_URL=http://127.0.0.1:19305 TELCO_SUBSCRIBER_URL=http://127.0.0.1:19401 TELCO_NETWORK_URL=http://127.0.0.1:19402 TELCO_COMMERCIAL_URL=http://127.0.0.1:19403 TELCO_POLICY_URL=http://127.0.0.1:19404 TELCO_BSS_URL=http://127.0.0.1:19406 TELCO_PORTAL_URL=http://127.0.0.1:19407 OPS_CONSOLE_URL=http://127.0.0.1:19409 node "$S/platform-portal/server.js" >"$TMP/platform.log" 2>&1 & PIDS+=("$!")

for port in 19301 19302 19303 19304 19305 19311 19312 19313 19320 19401 19402 19403 19404 19405 19406 19407 19408 19409 19410; do
  ok=0; for _ in {1..80}; do curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1 && { ok=1; break; }; sleep .1; done
  [[ "$ok" == 1 ]] || { echo "Service on port $port failed" >&2; grep -R . "$TMP" >&2 || true; exit 1; }
done

log "Validating local financial service graph"
curl -fsS 'http://127.0.0.1:19305/api/overview?customerId=C001' >"$TMP/overview.json"
curl -fsS -X POST http://127.0.0.1:19305/api/pay -H 'content-type: application/json' -d '{"transactionId":"TX-LOCAL-VALIDATION","customerId":"C001","amount":125.50,"currency":"BRL","beneficiaryName":"Validation Merchant","destinationCountry":"BR","deviceId":"device-maria-1","channel":"WEB"}' >"$TMP/payment.json"
curl -fsS -X POST http://127.0.0.1:19320/api/chat -H 'content-type: application/json' -d '{"prompt":"Summarize customer risk and compliance posture"}' >"$TMP/agent.json"

log "Validating local telecom and unified portal graph"
curl -fsS http://127.0.0.1:19407/api/subscriber/5511999999999 >"$TMP/subscriber.json"
curl -fsS -X POST http://127.0.0.1:19407/api/qod -H 'content-type: application/json' -d '{"subscriberId":"5511999999999","profile":"LOW_LATENCY","durationSeconds":900,"country":"BR"}' >"$TMP/qod.json"
curl -fsS -X POST http://127.0.0.1:19407/api/policy -H 'content-type: application/json' -d '{"partnerId":"partner-alpha","country":"BR","dataResidency":"OUTSIDE_BR","consent":"ACTIVE","action":"LOCATION"}' >"$TMP/policy.json"
curl -fsS http://127.0.0.1:19407/api/billing/5511999999999 >"$TMP/bss.json"
curl -fsS -X POST http://127.0.0.1:19408/mcp -H 'content-type: application/json' -H 'X-Partner-Id: partner-alpha' -H 'X-Correlation-ID: local-mcp-validation' -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"retrieveSubscriberServiceStatus","arguments":{"subscriberId":"5511999999999"}}}' >"$TMP/telco-mcp.json"
curl -fsS http://127.0.0.1:19410/api/status >"$TMP/platform.json"

python3 - "$TMP" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1])
ov=json.load(open(p/'overview.json')); pay=json.load(open(p/'payment.json')); ag=json.load(open(p/'agent.json'))
sub=json.load(open(p/'subscriber.json')); qod=json.load(open(p/'qod.json')); pol=json.load(open(p/'policy.json')); bss=json.load(open(p/'bss.json')); tm=json.load(open(p/'telco-mcp.json')); plat=json.load(open(p/'platform.json'))
assert ov['customer']['id']=='C001'
assert pay['status']=='ACCEPTED' and pay['cache']['status']=='NOT_CONFIGURED'
servers={t['server'] for t in ag['trace'] if t.get('ok')}; assert {'customer','risk','compliance'} <= servers,servers
assert sub['serviceStatus']=='ACTIVE' and qod['status']=='ACTIVE' and qod['authorization']['allowed'] and qod['policy']['decision']=='ALLOW' and qod['settlement']['partnerId']=='partner-alpha'
assert pol['decision']=='DENY' and 'BR_DATA_RESIDENCY' in pol['blockingFindings']
assert bss['mediation']=='SOAP/XML → REST/JSON'
assert tm['result']['structuredContent']['serviceStatus']=='ACTIVE' and tm['result']['structuredContent']['partnerId']=='partner-alpha'
assert plat['healthy']==plat['total']==8,plat
print('  financial orchestration: PASS')
print('  customer/risk/compliance MCP: PASS')
print('  telco subscriber + commercial QoD + policy + BSS + governed MCP: PASS')
print('  unified Platform Portal dependency graph: PASS')
PY
log "Local source integration validation PASSED"
