# Telecom repository → OpenChoreo adaptation

Source architecture studied: `https://github.com/joaokuntzwso2/demo-apim-telco-environment`.

The source repository combines WSO2 API Manager, Micro Integrator, telco/Open Gateway APIs, monetization/prepaid controls, policy enforcement, streaming/event processing, AI/MCP and observability. The default profile in this package adapts the **runtime domain capabilities** into lightweight OpenChoreo Components so the entire backend is visible in Kubernetes and remains practical on a development laptop.

## Mapping

| Source concern | OpenChoreo demo Component | Demonstration |
|---|---|---|
| Subscriber/BSS | `telco-subscriber-service` | service status, access network, SIM-swap/consent context |
| OSS/network | `telco-network-service` | outages, network summary, 5G QoD sessions |
| Commercial/prepaid | `telco-commercial-service` | partner wallet, authorize/settle model |
| Central governance | `telco-policy-service` | partner, consent and data-residency policy decisions |
| Legacy SOAP backend | `telco-legacy-billing` | XML billing endpoint |
| Integration façade | `telco-bss-facade` | SOAP/XML → REST/JSON mediation |
| Governed tool layer | `telco-mcp` | subscriber, outage, QoD, wallet and policy tools |
| Experience | `telco-portal` | operator-facing telecom UI |

## Why APIM and MI are not in the default profile

The goal of this package is to demonstrate OpenChoreo as the application/runtime platform and keep a clean-room laptop run deterministic. The original WSO2 product layer is therefore treated as an optional extension rather than a mandatory dependency for every run. The domain APIs are deliberately exposed as OpenChoreo endpoints so they can be inspected as Kubernetes Services/HTTPRoutes and later fronted by API Manager or an integration runtime without rewriting the domain code.


## Governed partner and MCP context

The adapted telco runtime preserves two operational patterns that are important in the source environment:

- externally exposed APIs propagate a correlation ID; the telecom experience uses `partner-alpha` as the default demonstration partner but accepts `X-Partner-Id` / `X-Correlation-ID` headers;
- the `telco-mcp` server requires both headers for tool execution. Its `requestQualityOnDemand` tool performs commercial authorization, central policy evaluation, network QoD creation and settlement as one governed tool flow.

Example MCP tool call after bootstrap (use the exact external route printed by `./demo.sh status`):

```bash
curl -X POST '<TELCO_MCP_URL>' \
  -H 'content-type: application/json' \
  -H 'X-Partner-Id: partner-alpha' \
  -H 'X-Correlation-ID: demo-001' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"retrieveSubscriberServiceStatus","arguments":{"subscriberId":"5511999999999"}}}'
```

## Source capability disposition

The original telco repository is intentionally broad. This package keeps the OpenChoreo clean-room profile focused on runtime/application-platform proof while documenting the disposition of the larger source architecture:

| Original repository capability | Disposition in this package |
|---|---|
| WSO2 API Manager lifecycle, Developer Portal, API Products, subscriptions, OAuth scopes and gateway quotas | **Optional extension.** The default profile exposes the domain APIs directly through OpenChoreo external endpoints/HTTPRoutes so their Kubernetes runtime is visible. APIM can later front those same endpoints without changing the domain services. |
| WSO2 Integrator / MI validation, REST/SOAP mediation, fan-out and fault normalization | **OpenChoreo-native adaptation.** Component dependencies provide orchestration/service discovery; `telco-bss-facade` demonstrates SOAP/XML → REST/JSON mediation with explicit timeout handling. Full MI remains optional when product-specific mediation is the demo goal. |
| Subscriber CRM, service status, SIM-swap and consent context | **Implemented** in `telco-subscriber-service`. |
| Network/OSS, outage and Quality-on-Demand | **Implemented** in `telco-network-service`. |
| Commercial plans, prepaid authorization, usage accounting and settlement | **Implemented** in `telco-commercial-service`; the QoD experience performs authorize → policy → network → settle. |
| Central OPA-style policy decisions and regional overlays | **Implemented as a lightweight policy decision Component** (`telco-policy-service`) for partner, consent, SIM-swap and residency rules. A real OPA engine can replace this endpoint without changing consumers. |
| Siddhi/Redpanda event-driven controls | **Not enabled by default** to keep the laptop profile bounded. OpenChoreo observability/events provide the platform-runtime story; the source repository remains the reference for the dedicated streaming-control overlay. |
| Governed AI/MCP tools | **Implemented** in `telco-mcp`, including partner/correlation headers and QoD commercial/policy orchestration. |
| Prometheus/Grafana/Loki/Tempo/Moesif/SIEM overlays | **Platform observability is supplied by OpenChoreo's observability plane** (Prometheus/OpenSearch/OpenTelemetry/Alertmanager). Source-specific Moesif/Loki/Tempo/SIEM overlays are optional extensions rather than duplicate default infrastructure. |
| Legacy SOAP billing primary/DR | **Implemented at demonstration level** by `telco-legacy-billing` plus `telco-bss-facade`. |

This separation is deliberate: the default profile proves that the telco estate itself is composed, governed, routed and observable as Kubernetes/OpenChoreo workloads. When the sales story is specifically WSO2 API management or MI mediation, the original repository's product overlays can be added in front of these exposed endpoints as a second layer rather than competing with the OpenChoreo platform demonstration.
