# Architecture

## Layers

```text
Browser
  ├─ Platform Portal
  ├─ Financial Services Experience / Financial Operations Agent
  ├─ Telecom Operations Experience
  ├─ Kubernetes Operations Console
  ├─ OpenChoreo Portal
  └─ Rancher

OpenChoreo Control Plane
  └─ Projects / Components / Workloads / Releases / Traits / Resources

OpenChoreo Data Plane (k3d Kubernetes)
  ├─ Financial domain Components
  ├─ Telecom domain Components
  ├─ Platform portal
  ├─ Kubernetes operations console
  └─ Managed Valkey resource

Observability Plane
  ├─ Prometheus
  ├─ OpenSearch
  ├─ OpenTelemetry
  ├─ Alertmanager
  ├─ SRE Agent (optional funded LLM key)
  └─ FinOps Agent (optional funded LLM key)

Workflow Plane
  └─ Argo / platform policy workflow

Host Docker
  ├─ Rancher (manages/registers the k3d cluster)
  └─ Platform webhook receiver (alert evidence sink)
```

## Financial component graph

`financial-bff → payments-service → fraud-service + compliance-service + payment-idempotency-cache`

`financial-agent → customer-mcp + risk-mcp + compliance-mcp (+ OpenChoreo MCP endpoints when available)`

## Telecom component graph

- `telco-bss-facade → telco-legacy-billing`
- `telco-mcp → subscriber + network + commercial + policy`
- `telco-portal → subscriber + network + commercial + policy + BSS façade`
- `platform-portal → financial-bff + telco domain services + Kubernetes ops console`

Cross-project connections are declared as OpenChoreo Workload endpoint dependencies so OpenChoreo injects the resolved addresses and generates the Kubernetes network policy relationships.

## Governance

The custom `regulated-platform` ProjectType generates each environment cell with ResourceQuota, LimitRange, Pod Security labels, a default-deny ingress policy and a runtime auditor Role. OpenChoreo then adds component-specific policies for declared dependencies and exposed endpoints.
