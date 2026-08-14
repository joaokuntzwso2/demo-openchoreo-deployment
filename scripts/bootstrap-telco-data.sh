#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
ensure_demo_context
log "Creating deterministic telecom demonstration activity"
PORTAL="$(external_url telco-portal || true)"
[[ -n "$PORTAL" ]] || die "Telco portal external route is not ready"

call(){
  local label="$1" method="$2" path="$3" data="${4:-}"
  local out="/tmp/platform-telco-${label}.json"
  if [[ "$method" == GET ]]; then
    curl -fsS --max-time 15 "$PORTAL$path" -o "$out"
  else
    curl -fsS --max-time 15 -X POST "$PORTAL$path" -H 'content-type: application/json' -d "$data" -o "$out"
  fi
  printf '%-18s %s\n' "$label" "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(d,separators=(",",":"))[:180])' "$out")"
}

call subscriber GET /api/subscriber/5511999999999
call network GET /api/network
call qod POST /api/qod '{"subscriberId":"5511999999999","profile":"LOW_LATENCY","durationSeconds":900,"country":"BR"}'
call wallet GET /api/wallet/partner-alpha
call policy-deny POST /api/policy '{"partnerId":"partner-alpha","country":"BR","dataResidency":"OUTSIDE_BR","consent":"ACTIVE","action":"LOCATION"}'
call legacy-bss GET /api/billing/5511999999999
log "Telecom bootstrap scenarios ready"
