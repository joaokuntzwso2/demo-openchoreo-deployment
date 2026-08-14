#!/usr/bin/env bash
# Refreshes the already-installed OpenChoreo built-in agents with a funded OpenAI API key.
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl
KEY="${OPENAI_API_KEY:-${1:-}}"
[[ -n "$KEY" ]] || die "Pass a funded OpenAI API key via OPENAI_API_KEY or as the first argument"

log "Updating OpenBao LLM secrets"
kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root bao kv put secret/rca-llm-api-key value="$KEY" >/dev/null
kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root bao kv put secret/finops-llm-api-key value="$KEY" >/dev/null
kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root bao kv put secret/portal-assistant-llm-api-key value="$KEY" >/dev/null

stamp="$(date +%s)"
log "Forcing External Secrets refresh"
kubectl annotate externalsecret rca-agent-secret -n openchoreo-observability-plane force-sync="$stamp" --overwrite >/dev/null
kubectl annotate externalsecret finops-agent -n openchoreo-observability-plane force-sync="$stamp" --overwrite >/dev/null
kubectl annotate externalsecret portal-assistant-secret -n openchoreo-control-plane force-sync="$stamp" --overwrite >/dev/null

# Wait until ESO reports the ExternalSecrets Ready, then restart consumers so they read the new Secret values.
kubectl wait --for=condition=Ready externalsecret/rca-agent-secret -n openchoreo-observability-plane --timeout=120s
kubectl wait --for=condition=Ready externalsecret/finops-agent -n openchoreo-observability-plane --timeout=120s
kubectl wait --for=condition=Ready externalsecret/portal-assistant-secret -n openchoreo-control-plane --timeout=120s

log "Restarting SRE, FinOps and Portal Assistant"
kubectl rollout restart deployment/sre-agent -n openchoreo-observability-plane >/dev/null
kubectl rollout restart deployment/finops-agent -n openchoreo-observability-plane >/dev/null
kubectl rollout restart deployment/portal-assistant -n openchoreo-control-plane >/dev/null

kubectl rollout status deployment/sre-agent -n openchoreo-observability-plane --timeout=300s
kubectl rollout status deployment/finops-agent -n openchoreo-observability-plane --timeout=300s
kubectl rollout status deployment/portal-assistant -n openchoreo-control-plane --timeout=300s

log "All three built-in AI services are Ready"
