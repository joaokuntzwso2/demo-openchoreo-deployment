#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib.sh"

need kubectl
need python3
ensure_demo_context

attach_openapi() {
  local workload="$1"
  local endpoint="$2"
  local display_name="$3"
  local spec_file="$4"

  [[ -f "$spec_file" ]] || die "OpenAPI definition not found: $spec_file"

  log "Publishing API schema: $display_name"

  local patch
  patch="$(
    python3 - "$endpoint" "$display_name" "$spec_file" <<'PY'
import json
import pathlib
import sys

endpoint = sys.argv[1]
display_name = sys.argv[2]
spec_file = pathlib.Path(sys.argv[3])

content = spec_file.read_text()

patch = {
    "spec": {
        "endpoints": {
            endpoint: {
                "displayName": display_name,
                "schema": {
                    "type": "openapi",
                    "content": content,
                },
            }
        }
    }
}

print(json.dumps(patch))
PY
  )"

  kubectl patch workload "$workload" \
    -n "$NS" \
    --type=merge \
    -p "$patch" \
    >/dev/null

  local schema_type
  schema_type="$(
    kubectl get workload "$workload" \
      -n "$NS" \
      -o "jsonpath={.spec.endpoints.${endpoint}.schema.type}"
  )"

  [[ "$schema_type" == "openapi" ]] \
    || die "Failed to attach OpenAPI schema to $workload/$endpoint"

  echo "  API published: $display_name"
}

attach_openapi \
  accounts-service \
  http \
  "Customer & Accounts API" \
  "$ROOT/platform/apis/accounts.yaml"

attach_openapi \
  payments-service \
  http \
  "Payments Orchestration API" \
  "$ROOT/platform/apis/payments.yaml"

attach_openapi \
  telco-subscriber-service \
  http \
  "Subscriber & Service Status API" \
  "$ROOT/platform/apis/telco-subscriber.yaml"

attach_openapi \
  telco-network-service \
  http \
  "Network Assurance & Quality on Demand API" \
  "$ROOT/platform/apis/telco-network.yaml"

log "OpenChoreo API catalog seeded successfully"
