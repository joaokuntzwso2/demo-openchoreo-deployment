#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need curl
URL="$(external_url financial-bff)"; [[ -n "$URL" ]] || die "BFF route unavailable"
log "Injecting a payment upstream failure that emits PAYMENT_UPSTREAM_FAILURE"
set +e
curl -sS -o /tmp/openchoreo-sre-demo.json -w 'HTTP %{http_code}\n' -X POST "$URL/api/pay" -H 'content-type: application/json' -d '{"transactionId":"TX-SRE-FAIL","customerId":"C001","amount":999.90,"currency":"BRL","beneficiaryName":"Failure Lab","beneficiaryCountry":"BR","simulate":"error"}'
set -e
cat /tmp/openchoreo-sre-demo.json | python3 -m json.tool || cat /tmp/openchoreo-sre-demo.json
log "The alert rule evaluates on its configured interval. Inspect OpenChoreo alerts/incidents and SRE RCA."
printf 'Portal: http://openchoreo.localhost:8080\n'
printf 'Webhook events: tail -f %s/runtime/alerts.ndjson\n' "$ROOT"
kubectl get pods -n openchoreo-observability-plane | grep -E 'rca|observer|opensearch|prometheus' || true
