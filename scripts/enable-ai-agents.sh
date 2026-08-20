#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
need kubectl; need helm
KEY="${OPENAI_API_KEY:-${1:-}}"; [[ -n "$KEY" ]] || die "Pass OPENAI_API_KEY as environment variable or first argument"
MODEL="${OPENCHOREO_AGENT_MODEL:-gpt-5.4}"

# Helm 4 uses server-side apply and reports field-manager conflicts. The official k3d
# installer applies cluster-gateway-ca with kubectl after Helm creates it, so a later
# Helm upgrade can legitimately conflict on data.ca.crt. Helm 4 exposes --force-conflicts
# precisely for this SSA case. Helm 3 does not need/support this flag.
HELM_SSA_ARGS=()
if helm upgrade --help 2>/dev/null | grep -q -- '--force-conflicts'; then
  HELM_SSA_ARGS+=(--server-side=true --force-conflicts)
fi

log "Storing LLM credentials in OpenBao"
kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root bao kv put secret/rca-llm-api-key value="$KEY" >/dev/null
kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root bao kv put secret/finops-llm-api-key value="$KEY" >/dev/null
kubectl exec -n openbao openbao-0 -- env BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root bao kv put secret/portal-assistant-llm-api-key value="$KEY" >/dev/null

log "Creating SRE and FinOps ExternalSecrets"
cat <<'YAML' | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: rca-agent-secret
  namespace: openchoreo-observability-plane
spec:
  refreshInterval: 1h
  secretStoreRef: {kind: ClusterSecretStore, name: default}
  target: {name: rca-agent-secret}
  data:
    - secretKey: RCA_LLM_API_KEY
      remoteRef: {key: rca-llm-api-key, property: value}
    - secretKey: OAUTH_CLIENT_SECRET
      remoteRef: {key: rca-oauth-client-secret, property: value}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: finops-agent
  namespace: openchoreo-observability-plane
spec:
  refreshInterval: 1h
  secretStoreRef: {kind: ClusterSecretStore, name: default}
  target: {name: finops-agent}
  data:
    - secretKey: LLM_API_KEY
      remoteRef: {key: finops-llm-api-key, property: value}
    - secretKey: OAUTH_CLIENT_SECRET
      remoteRef: {key: finops-agent-oauth-client-secret, property: value}
YAML
kubectl wait --for=condition=Ready externalsecret/rca-agent-secret -n openchoreo-observability-plane --timeout=120s
kubectl wait --for=condition=Ready externalsecret/finops-agent -n openchoreo-observability-plane --timeout=120s

log "Creating Portal Assistant ExternalSecret"
cat <<'YAML' | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: portal-assistant-secret
  namespace: openchoreo-control-plane
spec:
  refreshInterval: 1h
  secretStoreRef: {kind: ClusterSecretStore, name: default}
  target: {name: portal-assistant-secret}
  data:
    - secretKey: PORTAL_ASSISTANT_LLM_API_KEY
      remoteRef: {key: portal-assistant-llm-api-key, property: value}
YAML
kubectl wait --for=condition=Ready externalsecret/portal-assistant-secret -n openchoreo-control-plane --timeout=120s

log "Installing/updating the OpenCost FinOps module"
helm upgrade --install finops-opencost oci://ghcr.io/openchoreo/helm-charts/finops-opencost \
  --namespace openchoreo-observability-plane --create-namespace --version 0.1.2 "${HELM_SSA_ARGS[@]}"

log "Enabling OpenChoreo SRE RCA and FinOps agents"
helm upgrade --install openchoreo-observability-plane oci://ghcr.io/openchoreo/helm-charts/openchoreo-observability-plane \
  --version 1.2.2 --namespace openchoreo-observability-plane --reuse-values \
  --set-string security.oidc.jwksUrl="http://thunder-service.thunder.svc.cluster.local:8090/oauth2/jwks" \
  --set-string security.oidc.tokenUrl="http://thunder-service.thunder.svc.cluster.local:8090/oauth2/token" \
  --set-string security.oidc.authServerBaseUrl="http://thunder.openchoreo.localhost:8080" \
  --set rca.enabled=true \
  --set-string rca.llm.modelName="$MODEL" \
  --set-string rca.openchoreoApiUrl="http://api.openchoreo.localhost:8080" \
  --set-string 'rca.cors.allowedOrigins[0]=http://openchoreo.localhost:8080' \
  --set-string 'rca.http.hostnames[0]=rca-agent.openchoreo.localhost' \
  --set finOpsAgent.enabled=true \
  --set-string finOpsAgent.llmName="$MODEL" \
  --set finOpsAgent.remediationEnabled=true \
  --set-string finOpsAgent.openchoreoApiUrl="http://api.openchoreo.localhost:8080" \
  --set-string 'finOpsAgent.cors.allowedOrigins[0]=http://openchoreo.localhost:8080' \
  --set-string 'finOpsAgent.http.hostnames[0]=finops-agent.openchoreo.localhost' \
  --set gateway.httpPort=11080 \
  --set gateway.httpsPort=11085 \
  --set gateway.tls.enabled=false \
  "${HELM_SSA_ARGS[@]}"
kubectl patch clusterobservabilityplane default --type=merge \
  -p '{"spec":{"rcaAgentURL":"http://rca-agent.openchoreo.localhost:11080","finOpsAgentURL":"http://finops-agent.openchoreo.localhost:11080"}}' >/dev/null

log "Enabling Portal Assistant + Backstage assistant feature"
helm upgrade --install openchoreo-control-plane oci://ghcr.io/openchoreo/helm-charts/openchoreo-control-plane \
  --version 1.2.2 --namespace openchoreo-control-plane --reuse-values \
  --set portalAssistant.enabled=true \
  --set portalAssistant.llm.secretName=portal-assistant-secret \
  --set portalAssistant.llm.modelName="openai:$MODEL" \
  --set backstage.features.assistant.enabled=true \
  "${HELM_SSA_ARGS[@]}"

kubectl -n openchoreo-control-plane rollout restart deployment/backstage >/dev/null
kubectl -n openchoreo-control-plane rollout status deployment/backstage --timeout=240s
kubectl -n openchoreo-control-plane rollout status deployment/portal-assistant --timeout=240s
kubectl -n openchoreo-observability-plane rollout status deployment/sre-agent --timeout=240s
kubectl -n openchoreo-observability-plane rollout status deployment/finops-agent --timeout=240s

log "SRE, FinOps and Portal Assistant are enabled with model $MODEL"
