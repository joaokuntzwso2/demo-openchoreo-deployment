#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need helm
log "Inflating local OpenCost CPU/RAM pricing so the budget alert can fire during a short platform demo"
helm upgrade --install finops-opencost oci://ghcr.io/openchoreo/helm-charts/finops-opencost \
  --namespace openchoreo-observability-plane --create-namespace --version 0.1.2 --reuse-values \
  --set opencost.opencost.customPricing.costModel.CPU="50000" \
  --set opencost.opencost.customPricing.costModel.RAM="10000"
kubectl rollout restart deploy -n openchoreo-observability-plane opencost
log "Budget alert payment-budget-finops is configured to create an incident and trigger AI cost analysis."
printf 'Open OpenChoreo Portal -> payments-service -> Alerts/Incidents after the evaluation window.\n'
kubectl get pods -n openchoreo-observability-plane | grep -E 'finops|opencost|prometheus' || true
