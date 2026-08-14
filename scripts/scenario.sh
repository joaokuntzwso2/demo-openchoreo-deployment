#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need curl; need python3; need kubectl
ensure_demo_context
scenario="${1:-help}"
pretty(){ python3 -m json.tool 2>/dev/null || cat; }
fin(){ external_url financial-bff; }
telco(){ external_url telco-portal; }

payment(){
  local kind="$1" amount beneficiary device channel payload url
  case "$kind" in
    payment) amount=1250; beneficiary='Loja Exemplo SA'; device='device-maria-1'; channel='WEB' ;;
    challenge) amount=25000; beneficiary='Novo Beneficiario'; device='new-device-demo'; channel='WEB' ;;
    hold) amount=750; beneficiary='Test Sanctioned Person'; device='device-maria-1'; channel='WEB' ;;
    block) amount=80000; beneficiary='Treasury Demo'; device='new-device-demo'; channel='API' ;;
  esac
  url="$(fin)"; [[ -n "$url" ]] || die 'financial-bff external route is unavailable'
  payload="$(python3 - "$kind" "$amount" "$beneficiary" "$device" "$channel" <<'PY'
import json,sys,time
kind,amount,beneficiary,device,channel=sys.argv[1:]
print(json.dumps({"transactionId":f"TX-SCENARIO-{kind.upper()}-{int(time.time())}","customerId":"C001","amount":float(amount),"currency":"BRL","beneficiaryName":beneficiary,"destinationCountry":"BR","deviceId":device,"channel":channel}))
PY
)"
  log "Running financial scenario: $kind"
  curl -sS --max-time 15 -X POST "$url/api/pay" -H 'content-type: application/json' -d "$payload" | pretty
}

case "$scenario" in
  payment|challenge|hold|block) payment "$scenario" ;;
  qod)
    url="$(telco)"; log 'Creating a 5G Quality-on-Demand session';
    curl -sS --max-time 15 -X POST "$url/api/qod" -H 'content-type: application/json' -d '{"subscriberId":"5511999999999","profile":"LOW_LATENCY","durationSeconds":900,"country":"BR"}' | pretty ;;
  residency)
    url="$(telco)"; log 'Triggering a Brazil data-residency policy denial';
    curl -sS --max-time 15 -X POST "$url/api/policy" -H 'content-type: application/json' -d '{"partnerId":"partner-alpha","country":"BR","dataResidency":"OUTSIDE_BR","consent":"ACTIVE","action":"LOCATION"}' | pretty ;;
  legacy)
    url="$(telco)"; log 'Showing legacy SOAP billing through the REST/JSON BSS facade';
    curl -sS --max-time 15 "$url/api/billing/5511999999999" | pretty ;;
  self-heal)
    ns="$(kubectl get pod -A -l openchoreo.dev/component=payments-service -o jsonpath='{.items[0].metadata.namespace}')"
    pod="$(kubectl get pod -n "$ns" -l openchoreo.dev/component=payments-service -o jsonpath='{.items[0].metadata.name}')"
    [[ -n "$ns" && -n "$pod" ]] || die 'payments-service pod not found'
    log "Deleting $ns/$pod to demonstrate Kubernetes self-healing"
    kubectl delete pod -n "$ns" "$pod"
    deploy="$(kubectl get deploy -n "$ns" -l openchoreo.dev/component=payments-service -o jsonpath='{.items[0].metadata.name}')"
    kubectl rollout status deployment/"$deploy" -n "$ns" --timeout=180s
    newpod="$(kubectl get pod -n "$ns" -l openchoreo.dev/component=payments-service -o jsonpath='{.items[0].metadata.name}')"
    printf 'Old pod: %s\nNew pod: %s\n' "$pod" "$newpod" ;;
  policy-gate) "$ROOT/scripts/run-policy-gate.sh" ;;
  sre) "$ROOT/scripts/scenario-sre.sh" ;;
  finops) "$ROOT/scripts/scenario-finops.sh" ;;
  help|*)
    cat <<'USAGE'
Usage: ./demo.sh scenario <name>

Business scenarios:
  payment       accepted payment through Payments -> Fraud + Compliance + Valkey
  challenge     high-value/new-device fraud step-up
  hold          sanctions/compliance hold
  block         very-high-risk fraud block
  qod           5G Quality-on-Demand session
  residency     central data-residency policy denial
  legacy        SOAP/XML billing modernization through REST/JSON

Platform scenarios:
  self-heal     delete the Payments pod and watch Kubernetes recreate it
  policy-gate   execute the OpenChoreo workflow policy gate
  sre           inject PAYMENT_UPSTREAM_FAILURE for alert/RCA demonstration
  finops        inflate local OpenCost prices for the budget/FinOps story
USAGE
    [[ "$scenario" == help ]] || exit 2
    ;;
esac
