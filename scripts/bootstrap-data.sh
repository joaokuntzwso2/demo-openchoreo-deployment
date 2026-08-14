#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need curl; need python3

URL="$(external_url financial-bff)"
[[ -n "$URL" ]] || die "Financial BFF external route not found"

wait_overview(){
  local start=$SECONDS code
  while (( SECONDS - start < 120 )); do
    code="$(curl -sS -o /tmp/platform-financial-overview.json -w '%{http_code}' "$URL/api/overview?customerId=C001" 2>/dev/null || true)"
    if [[ "$code" == "200" ]] && python3 - <<'PY' >/dev/null 2>&1
import json
x=json.load(open('/tmp/platform-financial-overview.json'))
assert x['customer']['id']=='C001'
assert len(x['accounts'])>=2
PY
    then
      return 0
    fi
    sleep 2
  done
  die "Financial BFF did not become externally usable within 120s: $URL"
}

log "Loading deterministic financial scenarios through the externally routed Financial Experience"
wait_overview
python3 - <<'PY'
import json
x=json.load(open('/tmp/platform-financial-overview.json'))
print(f"Customer bootstrap: {x['customer']['name']} / {len(x['accounts'])} accounts / KYC {x['customer']['kyc']}")
PY

post_case(){
  local label="$1" payload="$2" expect="$3"
  local outfile="/tmp/platform-financial-${label}.json"
  local code
  code="$(curl -sS -o "$outfile" -w '%{http_code}' -X POST "$URL/api/pay" -H 'content-type: application/json' -d "$payload")"
  python3 - "$label" "$expect" "$code" "$outfile" <<'PY'
import json,sys
label,expect,code,path=sys.argv[1:]
x=json.load(open(path))
actual=x.get('status')
print(f"{label}: HTTP {code} / status={actual} / fraud={x.get('fraud',{}).get('decision')} / compliance={x.get('compliance',{}).get('decision')} / cache={x.get('cache',{}).get('status')}")
if actual != expect:
    raise SystemExit(f"Expected {expect}, got {actual}: {x}")
if x.get('cache',{}).get('status') != 'UP':
    raise SystemExit(f"Expected cache UP, got: {x}")
PY
}

post_case accepted '{"transactionId":"TX-BOOT-ACCEPT","customerId":"C001","amount":125.50,"currency":"BRL","beneficiaryName":"Padaria Central","destinationCountry":"BR","deviceId":"device-maria-1","channel":"WEB"}' ACCEPTED
post_case challenge '{"transactionId":"TX-BOOT-CHALLENGE","customerId":"C001","amount":25000,"currency":"BRL","beneficiaryName":"Novo Beneficiario","destinationCountry":"BR","deviceId":"new-demo-device","channel":"MOBILE"}' PENDING_CHALLENGE
post_case compliance-hold '{"transactionId":"TX-BOOT-HOLD","customerId":"C001","amount":750,"currency":"BRL","beneficiaryName":"Test Sanctioned Person","destinationCountry":"BR","deviceId":"device-maria-1","channel":"WEB"}' REJECTED
post_case fraud-block '{"transactionId":"TX-BOOT-BLOCK","customerId":"C001","amount":80000,"currency":"BRL","beneficiaryName":"Treasury Demo","destinationCountry":"BR","deviceId":"new-demo-device","channel":"API"}' REJECTED

log "Bootstrap data ready: accepted, challenged, compliance-held and fraud-blocked payment decisions are visible in the UI"
