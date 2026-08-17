# OpenChoreo Financial Services Showcase — Capability Map

This environment is designed to demonstrate **OpenChoreo as the developer platform** and **SUSE Rancher as complementary Kubernetes management/visibility**. Rancher is not presented as the OpenChoreo control plane.

## Story architecture

| Customer question | OpenChoreo capability shown | Live evidence |
|---|---|---|
| How do platform teams provide safe self-service? | ProjectTypes / platform abstractions / golden paths | `regulated-platform` creates per-environment Cell infrastructure, quotas, limits, security labels and baseline network policy |
| How is regulated software organized? | Namespaces, Projects, Components, Workloads, Cells | 10 Projects / 19 Components across financial services and telecom domains |
| How do changes move safely? | Immutable releases, ReleaseBindings, ProjectReleaseBindings, DeploymentPipeline | development → staging → production promotion |
| How are environment differences controlled? | Environment configuration and release binding overrides | environment-specific quotas, cache size and observability settings |
| How are dependencies handled? | Component endpoint dependencies and generated networking | payment/customer/risk/compliance dependency graph |
| How do teams consume platform services? | Resources and ResourceTypes | managed Valkey idempotency cache |
| How is cross-cutting behavior standardized? | Traits | observability/alert/RCA/FinOps configuration on services |
| How is access governed? | Declarative OpenChoreo authorization | scoped developer/auditor bindings; production restrictions |
| How are operational gates encoded? | Workflow Plane / Argo workflows | security-scan and change-ticket policy workflow |
| How do teams observe systems? | Logs, metrics, traces, alerts, incidents, RCA and cost views | OpenChoreo observability and Backstage entity views |
| How does AI assist operations? | SRE Agent, FinOps Agent, Portal Assistant | optional pre-enabled agents, using current supported model configuration |
| Can operators still see Kubernetes? | Open underlying Kubernetes data plane | Kubernetes Operations Console |
| Where does SUSE Rancher fit? | Complementary Kubernetes fleet/runtime management | imported OpenChoreo k3d cluster, namespaces, workloads and cluster agents visible in Rancher |

## Presentation rule

Use the **OpenChoreo Backstage portal as the primary platform evidence**. The custom portal is the scenario launcher and business-value view. Kubernetes Operations and Rancher are runtime evidence and operational views of the same underlying Kubernetes estate.

## Official documentation anchors

- OpenChoreo docs: https://openchoreo.dev/docs/
- Architecture: https://openchoreo.dev/docs/overview/architecture/
- Backstage-powered developer portal: https://openchoreo.dev/explore/backstage-powered-developer-portal/
- ProjectTypes: https://openchoreo.dev/docs/platform-engineer-guide/project-types/
- Authorization: https://openchoreo.dev/docs/platform-engineer-guide/authorization/
- GitOps: https://openchoreo.dev/docs/category/gitops/
- GitOps with Flux CD: https://openchoreo.dev/docs/platform-engineer-guide/gitops/using-flux-cd/
- SRE Agent: https://openchoreo.dev/docs/ai/sre-agent/
- Portal Assistant: https://openchoreo.dev/docs/ai/portal-assistant/

## Production-relevance caveat

The demo's local managed cache is intentionally a local showcase ResourceType. Do not characterize its embedded demo credentials/provisioning pattern as a production banking secret-management solution. The platform abstraction is the capability being demonstrated; a production installation should bind the ResourceType to the organization's approved managed service/provisioner and secret-management implementation.
