# OpenChoreo Platform Engineering & Agentic Operations Demo

A complete local platform-engineering showcase built on **OpenChoreo v1.2.2**, Kubernetes, k3d, OpenChoreo observability/workflow capabilities, managed-resource abstractions, reusable golden paths, policy gates, AI-assisted operations, MCP-based domain tooling, Kubernetes operations, and optional Rancher integration.

This repository demonstrates how an internal developer platform can use OpenChoreo as the application-platform abstraction layer while still exposing the underlying Kubernetes operational reality and layering organization-specific platform engineering standards on top.

The demo includes:

* a regulated financial-services domain;
* a telecom domain;
* reusable OpenChoreo project and component golden paths;
* custom OpenChoreo Traits;
* managed-resource abstractions;
* deployment pipelines and immutable release promotion;
* platform authorization and environment-specific governance;
* reusable workflow and release approval gates;
* application and infrastructure observability;
* alerts, incidents, AI-assisted RCA, and FinOps analysis;
* an OpenChoreo SRE Agent;
* an OpenChoreo FinOps Agent;
* the OpenChoreo Portal Assistant;
* a custom Financial Operations Agent;
* multiple MCP servers exposing business and platform tools;
* a Kubernetes operations console;
* a custom Platform Portal;
* optional Rancher integration;
* deterministic demo scenarios;
* clean-room rebuild and qualification automation.

The objective is to demonstrate not only **how applications run on OpenChoreo**, but also how a platform team can **extend OpenChoreo into an opinionated enterprise platform**.

## Quick Start

This repository is designed to be reproducible from a fresh clone. For the complete local showcase, the normal customer path is:

```bash
git clone https://github.com/joaokuntzwso2/demo-openchoreo-deployment.git
cd demo-openchoreo-deployment
./demo.sh reset
```

`./demo.sh reset` is the clean-room installation and acceptance path. It validates the workstation, installs OpenChoreo v1.2.2, creates the development/staging/production platform topology, applies the custom regulated platform abstractions, creates all 10 Projects and 30 ProjectReleaseBindings, builds and deploys all 19 application Components, provisions the managed Valkey resource, configures authorization and governance, starts the financial-services and telecom scenarios, starts Rancher when enabled, reconciles the 17 demo-owned Platform Artifacts, builds/deploys the enhanced OpenChoreo portal for the actual Kubernetes node architecture, and runs end-to-end verification.

No separate Platform Artifacts installer, metadata repair, manual `kubectl label`, Backstage build, or architecture-specific command is required for a healthy fresh clone.

### Prerequisites

Install Docker (or Colima), Docker Buildx, k3d, kubectl, Helm, curl, Python 3, and Git. For the full stack, use approximately 6 CPUs, 16 GiB RAM, and at least 25 GiB of free container-storage headroom.

On Apple Silicon with Colima:

```bash
colima start \
  --vm-type=vz \
  --vz-rosetta \
  --cpu 6 \
  --memory 16 \
  --disk 100
```

Confirm Docker is healthy:

```bash
docker info
docker system df
```

### Start from scratch

```bash
./demo.sh reset
```

A successful clean installation ends with:

```text
FULL CLEAN-ROOM RUN PASSED
```

The Platform Artifacts portal build is architecture-aware. The bootstrap detects the actual k3d node architecture and builds or reuses the matching `arm64` or `amd64` image automatically.

### Verify and obtain URLs

```bash
./demo.sh verify
./demo.sh status
./demo.sh capabilities
```

The primary interfaces are:

```text
OpenChoreo:
http://openchoreo.localhost:8080

Platform Artifacts:
http://openchoreo.localhost:8080/platform-artifacts
```

Application URLs are resolved dynamically and printed by `./demo.sh status`.

### Reconcile an existing installation

```bash
./demo.sh up
```

For reproducibility/customer qualification, use `./demo.sh reset`.

### Optional AI capabilities

The base showcase and Platform Artifacts UI do not require an OpenAI API key. To enable the OpenChoreo AI-assisted capabilities, provide the key only at runtime:

```bash
read -rsp "OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY
./demo.sh ai
unset OPENAI_API_KEY
```

Never commit the key.

---

# 1. Executive summary

The repository creates a complete local OpenChoreo platform running on a k3d Kubernetes cluster and deploys a multi-project application estate into it.

At the OpenChoreo application level, the demo currently contains:

* **3 environments**

  * development
  * staging
  * production
* **1 standard deployment pipeline**
* **10 OpenChoreo Projects**
* **30 ProjectReleaseBindings**
* **19 application Components**
* multiple Workloads, ComponentReleases, ReleaseBindings, and RenderedReleases
* **1 custom regulated ClusterProjectType**
* **1 custom regulated ClusterComponentType**
* **1 custom runtime-hardening ClusterTrait**
* **1 custom ClusterResourceType**
* **1 managed Valkey Resource**
* environment-specific ResourceReleaseBindings
* **1 namespaced policy Workflow**
* **1 reusable ClusterWorkflow release gate**
* OpenChoreo Authz roles and bindings
* environment-specific alert notification channels
* alert rules capable of creating incidents and invoking AI-assisted RCA or FinOps analysis

The repository also runs additional supporting infrastructure outside or alongside the OpenChoreo application model:

* Rancher, optionally;
* a webhook receiver for alert evidence;
* local image build/import automation;
* platform validation and qualification tooling.

---

# 2. What this demo is intended to prove

This demo is designed around several platform-engineering questions.

## 2.1 Can platform teams create organization-specific golden paths?

Yes.

The repository creates both:

* a regulated **ProjectType** defining how project/environment cells are provisioned; and
* a regulated **ComponentType** defining how services are deployed.

The platform team can therefore encode organizational requirements once and let application teams consume them declaratively.

---

## 2.2 Can security controls be embedded rather than manually applied?

Yes.

The custom `bank-runtime-hardening` Trait automatically applies runtime controls such as:

* `automountServiceAccountToken: false`;
* `seccompProfile: RuntimeDefault`;
* `allowPrivilegeEscalation: false`;
* dropping all Linux capabilities;
* creation of a PodDisruptionBudget.

The regulated service ComponentType embeds this Trait as a mandatory baseline.

Applications consuming the golden path therefore inherit the controls automatically.

---

## 2.3 Can a platform define environment-specific infrastructure boundaries?

Yes.

The custom regulated ProjectType creates per-project/per-environment Kubernetes controls including:

* namespaces;
* ResourceQuotas;
* LimitRanges;
* default-deny NetworkPolicies;
* auditor Roles;
* platform metadata.

Development, staging, and production have different capacity settings.

---

## 2.4 Can services consume managed resources through platform abstractions?

Yes.

The demo defines a `ClusterResourceType` representing a managed Valkey cache.

The `payments-service` consumes the cache through an OpenChoreo Resource dependency rather than manually embedding Kubernetes Service/Secret knowledge into the application.

---

## 2.5 Can production promotion be governed?

Yes.

The repository demonstrates two workflow styles:

1. a namespaced `platform-policy-gate` Workflow;
2. a reusable cluster-scoped `regulated-release-gate` ClusterWorkflow.

The regulated production gate evaluates:

* security scan status;
* risk assessment;
* change-ticket evidence;
* approval evidence.

The demo includes explicit pass and fail scenarios.

---

## 2.6 Can developer authorization differ between development and production?

Yes.

OpenChoreo authorization bindings grant developer capabilities while restricting production release modifications.

Auditors receive read-oriented access to application and observability resources.

This is separate from Kubernetes RBAC used by the Kubernetes operations console.

---

## 2.7 Can an immutable release be promoted instead of rebuilt?

Yes.

The promotion scenario demonstrates promoting the same `ComponentRelease` from development through staging and production.

The intent is:

```text
build once
   ↓
ComponentRelease
   ↓
development
   ↓
staging
   ↓
production
```

rather than rebuilding independently for each environment.

---

## 2.8 Can OpenChoreo observability trigger operational AI?

Yes.

The payments service includes alert traits demonstrating:

* application-error detection;
* CPU monitoring;
* budget/cost monitoring;
* incident generation;
* SRE/RCA triggering;
* FinOps analysis triggering.

---

## 2.9 Can AI agents operate through governed tools instead of direct database access?

Yes.

The Financial Operations Agent discovers and invokes tools exposed over MCP by:

* OpenChoreo control-plane MCP;
* OpenChoreo observability MCP;
* Customer MCP;
* Risk MCP;
* Compliance MCP.

The telecom domain also exposes governed operational actions through a dedicated MCP server.

---

# 3. Architecture

At a high level:

```text
                               ┌─────────────────────────────┐
                               │          Browser            │
                               └──────────────┬──────────────┘
                                              │
              ┌───────────────────────────────┼────────────────────────────────┐
              │                               │                                │
              ▼                               ▼                                ▼
   ┌─────────────────────┐       ┌──────────────────────┐        ┌──────────────────────┐
   │ OpenChoreo Portal   │       │ Platform Demo Portal │        │ Rancher              │
   │ / Portal Assistant  │       │ Business scenarios   │        │ optional cluster ops │
   └──────────┬──────────┘       └───────────┬──────────┘        └──────────────────────┘
              │                              │
              │                              ├───────────────────────────────┐
              │                              │                               │
              ▼                              ▼                               ▼
┌──────────────────────────────┐  ┌─────────────────────────┐   ┌────────────────────────┐
│ OpenChoreo Control Plane     │  │ Financial Experience    │   │ Telecom Experience     │
│                              │  │                         │   │                        │
│ Projects                     │  │ Financial BFF           │   │ Telco Portal           │
│ Components                   │  │ Financial Ops Agent     │   │ Telco MCP              │
│ Workloads                    │  └────────────┬────────────┘   └───────────┬────────────┘
│ Releases                     │               │                            │
│ Traits                       │               ▼                            ▼
│ Resources                    │     ┌──────────────────────┐     ┌───────────────────────┐
│ Workflows                    │     │ Financial domain     │     │ Telecom domain        │
│ Authorization                │     │ Accounts              │     │ Subscriber            │
└─────────────┬────────────────┘     │ Payments              │     │ Network               │
              │                      │ Fraud/Risk            │     │ Commercial            │
              │                      │ Compliance            │     │ Policy                │
              │                      │ MCP servers           │     │ Legacy Billing/BSS    │
              │                      └──────────────────────┘     └───────────────────────┘
              │
              ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes Data Plane                               │
│                                                                               │
│ Namespaces · Deployments · Services · HTTPRoutes · Secrets · ConfigMaps       │
│ ResourceQuotas · LimitRanges · NetworkPolicies · PDBs · StatefulSets          │
└─────────────────────────────────┬─────────────────────────────────────────────┘
                                  │
                                  ▼
                     ┌─────────────────────────┐
                     │ Observability Plane     │
                     │                         │
                     │ Metrics                 │
                     │ Logs                    │
                     │ Traces                  │
                     │ Alerts                  │
                     │ Incidents               │
                     │ SRE/RCA Agent           │
                     │ FinOps Agent            │
                     │ OpenCost                │
                     └─────────────────────────┘
```

---

# 4. OpenChoreo versus repository extensions

It is important to distinguish the layers.

## OpenChoreo provides the platform primitives

Examples include:

* Projects;
* Components;
* Workloads;
* ComponentReleases;
* ReleaseBindings;
* Environments;
* DeploymentPipelines;
* ProjectTypes;
* ComponentTypes;
* Traits;
* Resources;
* ResourceTypes;
* Workflows;
* authorization;
* observability;
* MCP surfaces;
* workflow execution;
* SRE/FinOps integrations.

## This repository creates organization-specific platform engineering on top

Examples include:

* `regulated-platform`;
* `regulated-service`;
* `bank-runtime-hardening`;
* `platform-valkey-cache`;
* `platform-policy-gate`;
* `regulated-release-gate`;
* project-specific quotas;
* project classifications;
* banking-specific policy choices;
* demo applications;
* MCP business tools;
* Platform Portal;
* Financial Operations Agent;
* Kubernetes operations console.

## Rancher is complementary

Rancher is **not** the OpenChoreo control plane.

In this demo it provides a separate infrastructure/operator view of the Kubernetes cluster.

The intended separation is:

```text
OpenChoreo
    application platform / developer abstraction

Kubernetes
    underlying runtime

Rancher
    optional infrastructure and cluster operations view
```

---

# 5. Repository layout

```text
.
├── README.md
├── demo.sh
├── apply_openchoreo_showcase_upgrade.sh
├── .showcase.env.example
│
├── platform/
│   ├── authz/
│   │   └── roles-bindings.yaml
│   │
│   ├── components/
│   │   ├── compliance.yaml
│   │   ├── customer.yaml
│   │   ├── experience.yaml
│   │   ├── ops.yaml
│   │   ├── payments.yaml
│   │   ├── platform-portal.yaml
│   │   ├── risk.yaml
│   │   └── telco.yaml
│   │
│   ├── 00-namespace.yaml
│   ├── 00-platform-projecttype-dataplane-rbac.yaml
│   ├── 01-regulated-platform-project-type.yaml
│   ├── 02-environments-pipeline.yaml
│   ├── 03-projects-and-bindings.yaml
│   ├── 04-alert-notification-channels.yaml
│   ├── 05-resource-type.yaml
│   ├── 06-payment-cache.yaml
│   ├── 07-platform-policy-workflow.yaml
│   ├── 08-k8s-ops-rbac.yaml
│   ├── 09-bank-runtime-hardening-trait.yaml
│   ├── 10-regulated-release-gate-clusterworkflow.yaml
│   └── 11-regulated-service-clustercomponenttype.json
│
├── services/
│   ├── accounts-service/
│   ├── compliance-service/
│   ├── financial-agent/
│   ├── financial-bff/
│   ├── fraud-service/
│   ├── k8s-ops-console/
│   ├── mcp-compliance/
│   ├── mcp-customer/
│   ├── mcp-risk/
│   ├── payments-service/
│   ├── platform-portal/
│   ├── platform-webhook-receiver/
│   ├── telco-bss-facade/
│   ├── telco-commercial-service/
│   ├── telco-legacy-billing/
│   ├── telco-mcp/
│   ├── telco-network-service/
│   ├── telco-policy-service/
│   ├── telco-portal/
│   └── telco-subscriber-service/
│
├── scripts/
│   └── ...
│
└── docs/
    ├── ARCHITECTURE.md
    ├── DEMO-RUNBOOK.md
    ├── RANCHER.md
    ├── SHOWCASE-CAPABILITY-MAP.md
    ├── SHOWCASE-RUNBOOK.md
    ├── TELCO-OPENCHOREO-ADAPTATION.md
    ├── TROUBLESHOOTING.md
    └── VALIDATION.md
```

`services/platform-webhook-receiver` is support infrastructure rather than one of the 19 OpenChoreo application Components.

---

# 6. Complete custom OpenChoreo platform artifact inventory

The following artifacts are easy to miss when looking only at the application Components.

They are core to the platform-engineering story.

| File                                             | Artifact                                           | Purpose                                                                    |
| ------------------------------------------------ | -------------------------------------------------- | -------------------------------------------------------------------------- |
| `00-namespace.yaml`                              | Namespace `platform-demo`                          | OpenChoreo control-plane namespace for the demo                            |
| `00-platform-projecttype-dataplane-rbac.yaml`    | ClusterRole + ClusterRoleBinding                   | Allows the data-plane agent to materialize regulated ProjectType resources |
| `01-regulated-platform-project-type.yaml`        | `ClusterProjectType/regulated-platform`            | Regulated project/environment golden path                                  |
| `02-environments-pipeline.yaml`                  | 3 Environments                                     | development, staging, production                                           |
| `02-environments-pipeline.yaml`                  | `DeploymentPipeline/platform-standard`             | dev → staging → production                                                 |
| `03-projects-and-bindings.yaml`                  | 10 Projects                                        | business/platform domains                                                  |
| `03-projects-and-bindings.yaml`                  | 30 ProjectReleaseBindings                          | 10 projects × 3 environments                                               |
| `04-alert-notification-channels.yaml`            | 3 notification channels                            | environment-specific webhook alert routing                                 |
| `05-resource-type.yaml`                          | `ClusterResourceType/platform-valkey-cache`        | managed-cache abstraction                                                  |
| `06-payment-cache.yaml`                          | `Resource/payment-idempotency-cache`               | payments cache instance                                                    |
| `06-payment-cache.yaml`                          | ResourceReleaseBindings                            | environment-specific cache configuration                                   |
| `07-platform-policy-workflow.yaml`               | `Workflow/platform-policy-gate`                    | namespaced release-policy gate                                             |
| `08-k8s-ops-rbac.yaml`                           | ClusterRole + binding                              | real Kubernetes operations for the ops console                             |
| `09-bank-runtime-hardening-trait.yaml`           | `ClusterTrait/bank-runtime-hardening`              | reusable banking runtime security baseline                                 |
| `10-regulated-release-gate-clusterworkflow.yaml` | `ClusterWorkflow/regulated-release-gate`           | reusable governed release approval                                         |
| `11-regulated-service-clustercomponenttype.json` | `ClusterComponentType/regulated-service`           | reusable regulated-service deployment golden path                          |
| `authz/roles-bindings.yaml`                      | AuthzRole/AuthzRoleBinding/ClusterAuthzRoleBinding | OpenChoreo authorization policy                                            |

---

# 7. The regulated Project golden path

## `ClusterProjectType/regulated-platform`

This custom ProjectType is one of the most important artifacts in the repository.

It allows each Project to declare business/platform metadata:

### Data classification

```text
INTERNAL
CONFIDENTIAL
RESTRICTED
```

Default:

```text
CONFIDENTIAL
```

### Criticality

```text
STANDARD
HIGH
MISSION_CRITICAL
```

Default:

```text
HIGH
```

### Cost center

A required organizational identifier.

Examples used by the demo include:

```text
FIN-PAY
FIN-RISK
FIN-CUST
FIN-COMP
TELCO-CORE
TELCO-NET
TELCO-COMM
TELCO-EXP
PLAT-EXP
PLAT-OPS
```

---

## 7.1 What the ProjectType creates

For every Project/environment cell, the ProjectType can materialize Kubernetes resources such as:

### Namespace

The generated namespace includes platform metadata representing concepts such as:

* classification;
* criticality;
* cost center;
* regulated workload designation.

Pod Security Admission metadata is also applied.

---

### ResourceQuota

Environment-specific quotas restrict values such as:

```text
limits.cpu
limits.memory
pods
```

---

### LimitRange

Default container sizing is established.

The demo baseline includes values equivalent to:

```text
requests.cpu:     50m
requests.memory:  64Mi

limits.cpu:       500m
limits.memory:    256Mi
```

unless overridden by component configuration.

---

### Default-deny ingress NetworkPolicy

The regulated cells can start from a default-deny ingress posture.

Explicit application dependencies are then used to establish permitted communication paths.

---

### Auditor Role

A read-oriented Kubernetes Role is created for operational/audit visibility into resources such as:

* Pods;
* Services;
* ConfigMaps;
* Events;
* HTTPRoutes.

---

# 8. ProjectType materialization RBAC

The ProjectType needs permission to create its generated Kubernetes resources in the data plane.

For that reason the repository includes:

```text
00-platform-projecttype-dataplane-rbac.yaml
```

It grants the OpenChoreo data-plane agent the necessary access for resources including:

* ResourceQuotas;
* LimitRanges;
* NetworkPolicies;
* Roles.

This is operationally important.

Without the associated permissions, a perfectly valid ProjectType definition could exist in the control plane but fail when OpenChoreo attempts to render it into the data plane.

The bootstrap explicitly verifies these permissions.

---

# 9. Environments

The demo defines three OpenChoreo Environments.

## Development

```text
development
isProduction: false
```

## Staging

```text
staging
isProduction: false
```

## Production

```text
production
isProduction: true
```

All use the local default ClusterDataPlane in this laptop deployment.

---

# 10. Deployment pipeline

The standard pipeline is:

```text
development
     │
     ▼
staging
     │
     ▼
production
```

Artifact:

```text
DeploymentPipeline/platform-standard
```

The promotion scenarios are designed to demonstrate that the **same immutable ComponentRelease** moves through this pipeline.

---

# 11. Projects

The repository creates ten Projects.

| Project            | Classification | Criticality      | Cost Center |
| ------------------ | -------------- | ---------------- | ----------- |
| `experience`       | RESTRICTED     | MISSION_CRITICAL | PLAT-EXP    |
| `payments`         | RESTRICTED     | MISSION_CRITICAL | FIN-PAY     |
| `risk`             | RESTRICTED     | HIGH             | FIN-RISK    |
| `customer`         | RESTRICTED     | HIGH             | FIN-CUST    |
| `compliance`       | RESTRICTED     | MISSION_CRITICAL | FIN-COMP    |
| `telco-core`       | RESTRICTED     | HIGH             | TELCO-CORE  |
| `telco-network`    | INTERNAL       | MISSION_CRITICAL | TELCO-NET   |
| `telco-commercial` | RESTRICTED     | HIGH             | TELCO-COMM  |
| `telco-experience` | INTERNAL       | HIGH             | TELCO-EXP   |
| `platform-ops`     | INTERNAL       | HIGH             | PLAT-OPS    |

Every project uses:

```text
ClusterProjectType/regulated-platform
```

and:

```text
DeploymentPipeline/platform-standard
```

---

# 12. Environment capacity configuration

Each of the ten Projects receives three ProjectReleaseBindings.

That produces:

```text
10 projects × 3 environments = 30 ProjectReleaseBindings
```

Typical environment settings are:

## Development

```text
CPU quota:       3
Memory quota:    4Gi
Pod quota:       15
Default ingress: deny
```

## Staging

```text
CPU quota:       4
Memory quota:    6Gi
Pod quota:       20
Default ingress: deny
```

## Production

```text
CPU quota:       8
Memory quota:    12Gi
Pod quota:       40
Default ingress: deny
```

This demonstrates a single platform abstraction producing different runtime boundaries by environment.

---

# 13. Regulated service golden path

## `ClusterComponentType/regulated-service`

The repository creates a reusable regulated application deployment type.

`payments-service` intentionally consumes this ComponentType.

The point is to demonstrate that developers can declare:

```text
I need a regulated service
```

rather than manually reproducing:

* Deployment;
* Service;
* routes;
* configuration projection;
* secrets integration;
* security controls;
* resilience controls.

---

## 13.1 Runtime configuration supported by the golden path

The ComponentType supports platform-level settings such as:

### Image pull policy

```text
Always
IfNotPresent
Never
```

Default:

```text
IfNotPresent
```

### Replicas

Default:

```text
1
```

### Resource configuration

Default baseline roughly equivalent to:

```yaml
requests:
  cpu: 100m
  memory: 256Mi
```

with corresponding limits supplied through the ComponentType configuration.

---

## 13.2 Resources rendered by the ComponentType

The golden path can render:

* Deployment;
* Service;
* external HTTPRoute;
* internal HTTPRoute;
* environment ConfigMaps;
* file ConfigMaps;
* ExternalSecrets for secret dependencies.

It contains validation for endpoint and gateway configuration.

---

## 13.3 Supported build workflows

The regulated ComponentType is designed to coexist with OpenChoreo builder workflows including:

* Paketo buildpacks;
* GCP buildpacks;
* Dockerfile builder;
* Ballerina buildpack builder.

The laptop demo itself normally prebuilds/imports local images into the k3d runtime for deterministic execution.

---

# 14. Hidden mandatory hardening Trait

## `ClusterTrait/bank-runtime-hardening`

The banking runtime hardening Trait is a reusable organization-controlled security policy.

It defines a compliance-profile parameter:

```text
BASELINE
PCI-DSS
SOX
```

Default:

```text
PCI-DSS
```

The Trait patches generated workloads with controls including:

```yaml
automountServiceAccountToken: false
```

Pod-level seccomp:

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

Container-level hardening:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

It also creates a:

```text
PodDisruptionBudget
```

with:

```text
maxUnavailable: 1
```

for the component.

---

## 14.1 Why this Trait matters

The application developer does **not** have to remember to add these controls individually.

The `regulated-service` ComponentType embeds an instance of:

```text
ClusterTrait/bank-runtime-hardening
```

as the regulated runtime baseline.

This is the platform-engineering pattern:

```text
platform requirement
       ↓
reusable Trait
       ↓
golden ComponentType
       ↓
developer Component
       ↓
generated compliant Kubernetes workload
```

---

# 15. Observability Traits on payments-service

The payments component also demonstrates OpenChoreo observability alert traits.

The repository defines three notable rules.

## Payment error / RCA alert

Detects the application log signature:

```text
PAYMENT_UPSTREAM_FAILURE
```

The development binding enables:

* alert delivery;
* incident generation;
* AI RCA triggering.

Conceptually:

```text
payment failure
      ↓
log event
      ↓
alert
      ↓
incident
      ↓
SRE Agent / RCA analysis
```

---

## CPU warning

A metric alert monitors CPU usage.

The demo threshold is configured around:

```text
cpu_usage >= 75
```

for the configured evaluation window.

---

## Budget / FinOps alert

A budget-oriented alert is configured for the payments workload.

The development configuration enables:

```text
triggerAiCostAnalysis: true
```

Conceptually:

```text
cost/budget threshold
       ↓
alert
       ↓
incident
       ↓
FinOps Agent
       ↓
cost analysis
```

---

# 16. Alert notification channels

The repository creates separate notification channels for:

* development;
* staging;
* production.

They send webhook notifications to the local demo webhook receiver.

The receiver is reachable by the cluster through:

```text
host.k3d.internal:18081
```

and persists received alert evidence locally.

Useful command:

```bash
tail -f runtime/alerts.ndjson
```

This allows a presenter to demonstrate that alert delivery is real rather than only represented in a UI.

---

# 17. Managed resources

## `ClusterResourceType/platform-valkey-cache`

The repository defines its own ResourceType for a Valkey cache.

This demonstrates the OpenChoreo pattern:

```text
application requests a platform resource
               ↓
        ResourceType
               ↓
 platform decides how it is provisioned
               ↓
 bindings expose connection information
```

---

## 17.1 What the local ResourceType creates

For this local demo the ResourceType renders:

* a Secret;
* a Service;
* a StatefulSet;
* a NetworkPolicy.

The runtime image is based on:

```text
valkey/valkey:8.1.5-alpine
```

The cache listens on:

```text
6379
```

and requires authentication.

---

## 17.2 Resource outputs

The ResourceType publishes connection outputs conceptually equivalent to:

```text
host
port
password
```

The host resolves to the generated Kubernetes service.

The password comes from the generated Secret.

---

# 18. Payments managed cache

The resource instance is:

```text
Resource/payment-idempotency-cache
```

under the payments domain.

Environment-specific ResourceReleaseBindings configure capacity.

Typical demo settings are:

| Environment | Cache memory |
| ----------- | -----------: |
| development |        128Mi |
| staging     |        256Mi |
| production  |        512Mi |

Production also demonstrates a retain-oriented lifecycle configuration.

---

## 18.1 Application binding

`payments-service` consumes the managed Resource and receives values equivalent to:

```text
VALKEY_HOST
VALKEY_PORT
VALKEY_PASSWORD
```

without embedding the generated service/secret names in application source.

That is one of the central managed-resource capabilities demonstrated by the repository.

---

## 18.2 Important production caveat

The Valkey implementation is deliberately local-demo friendly.

It should **not** be interpreted as the recommended production implementation.

A production ResourceType would normally integrate with something such as:

* a cloud-managed cache service;
* an infrastructure operator;
* Crossplane;
* another approved infrastructure provisioning mechanism;
* an enterprise secret manager.

The local password/value used by the demo is not intended to be a production secret-management design.

---

# 19. Governance workflows

The demo contains two distinct workflow/gate patterns.

---

# 19.1 Namespaced policy gate

Artifact:

```text
Workflow/platform-policy-gate
```

Inputs include:

```text
release
environment
changeTicket
securityScan
```

The security scan can be:

```text
PASS
FAIL
```

A failed scan blocks the workflow.

For production, the workflow also records the change/governance evidence supplied by the caller.

Run the scenario with:

```bash
./demo.sh scenario policy-gate
```

---

# 19.2 Reusable regulated ClusterWorkflow

Artifact:

```text
ClusterWorkflow/regulated-release-gate
```

This represents a cluster-wide reusable production governance control.

Inputs include:

```text
release
environment
changeTicket
securityScan
riskAssessment
approvedBy
```

Supported risk values include:

```text
LOW
MEDIUM
HIGH
```

The workflow denies releases when conditions such as the following occur:

* security scan is not `PASS`;
* risk is `HIGH`;
* production has no change ticket;
* production has no approver.

This means the demo has a genuine negative path rather than only a successful "policy demo."

---

## 19.3 Pass scenario

```bash
./scripts/run-regulated-release-gate.sh pass production
```

or:

```bash
./demo.sh scenario regulated-gate-pass
```

The demo provides valid evidence such as:

```text
security scan: PASS
risk: LOW
change ticket: present
approver: present
```

---

## 19.4 Fail scenario

```bash
./scripts/run-regulated-release-gate.sh fail production
```

or:

```bash
./demo.sh scenario regulated-gate-fail
```

The failing scenario intentionally uses invalid governance evidence.

Inspect WorkflowRuns:

```bash
kubectl get workflowrun -n platform-demo \
  --sort-by=.metadata.creationTimestamp
```

---

# 20. OpenChoreo authorization

The repository contains OpenChoreo authorization definitions in:

```text
platform/authz/roles-bindings.yaml
```

This is different from Kubernetes RBAC.

---

## 20.1 Platform auditor

The custom:

```text
AuthzRole/platform-auditor
```

provides read-oriented access to platform/application resources and observability information including concepts such as:

* namespaces/projects;
* components;
* resources;
* release bindings;
* logs;
* metrics;
* traces;
* alerts;
* incidents;
* RCA reports;
* FinOps reports.

---

## 20.2 Platform developers

The cluster authorization binding grants the:

```text
platform-developers
```

group developer-oriented capabilities.

A critical rule restricts creation/update of production release bindings.

Conceptually:

```text
developer can operate development/staging
               ↓
production release mutation is restricted
```

The same developer role can have more limited observability visibility outside non-production environments.

---

## 20.3 Platform auditors

The:

```text
platform-auditors
```

group is bound to the platform auditor role.

---

# 21. Kubernetes operations RBAC

The Kubernetes operations console needs real Kubernetes API permissions.

For this reason the repository separately defines:

```text
platform-demo-k8s-ops
```

RBAC.

It supports operations including:

* read Pods;
* read Services;
* read Events;
* read Namespaces;
* delete Pods;
* read/watch Deployments;
* patch Deployments;
* read NetworkPolicies;
* read HTTPRoutes;
* inspect selected OpenChoreo resources.

This allows the demo to show actual Kubernetes behavior such as deleting a Pod and observing recovery.

Again:

```text
OpenChoreo authorization != Kubernetes RBAC
```

They solve different problems and the repository demonstrates both.

---

# 22. Application inventory

There are **19 OpenChoreo application Components**.

---

# 22.1 Financial-services domain

| Component            | Project    | Purpose                          |
| -------------------- | ---------- | -------------------------------- |
| `accounts-service`   | customer   | customer/account data            |
| `customer-mcp`       | customer   | customer MCP tool surface        |
| `fraud-service`      | risk       | deterministic fraud scoring      |
| `risk-mcp`           | risk       | risk MCP tool surface            |
| `compliance-service` | compliance | sanctions/payment compliance     |
| `compliance-mcp`     | compliance | compliance MCP tool surface      |
| `payments-service`   | payments   | payment orchestration            |
| `financial-bff`      | experience | financial experience aggregation |
| `financial-agent`    | experience | Financial Operations Agent       |

---

# 22.2 Platform and operations

| Component         | Project      | Purpose                              |
| ----------------- | ------------ | ------------------------------------ |
| `platform-portal` | experience   | unified demo/business portal         |
| `k8s-ops-console` | platform-ops | real Kubernetes operational evidence |

---

# 22.3 Telecom domain

| Component                  | Project          | Purpose                           |
| -------------------------- | ---------------- | --------------------------------- |
| `telco-subscriber-service` | telco-core       | subscriber service information    |
| `telco-legacy-billing`     | telco-core       | legacy billing simulation         |
| `telco-bss-facade`         | telco-core       | modern facade over legacy billing |
| `telco-network-service`    | telco-network    | network/QoD operations            |
| `telco-commercial-service` | telco-commercial | commercial authorization/wallet   |
| `telco-policy-service`     | telco-commercial | telco policy decisions            |
| `telco-mcp`                | telco-network    | governed MCP orchestration        |
| `telco-portal`             | telco-experience | telecom experience                |

---

# 23. Financial domain

The financial demo models a regulated payment flow.

```text
Financial experience
        │
        ▼
  Financial BFF
        │
        ├───────────────► Accounts
        │
        └───────────────► Payments
                              │
                              ├────────► Fraud/Risk
                              │
                              ├────────► Compliance
                              │
                              └────────► Managed Valkey cache
```

Cross-project service relationships are declared through OpenChoreo Workload dependencies.

The platform then resolves service connectivity for the target environment.

---

# 24. Accounts service

The accounts service contains deterministic demo customers and accounts.

A representative customer is:

```text
C001
Maria Silva
```

The API exposes operations such as:

```text
GET /api/customers
GET /api/customers/:id
GET /api/customers/:id/accounts
GET /api/accounts/:id
```

The deterministic dataset keeps scenario results reproducible.

---

# 25. Fraud service

The fraud service implements deterministic scoring rules.

Signals include concepts such as:

* transaction amount;
* unusually high amount;
* destination country;
* known/unknown device;
* channel.

The outcome is one of:

```text
ALLOW
CHALLENGE
BLOCK
```

The scoring thresholds allow the demo to reliably generate all three paths.

The service also exposes:

```text
POST /api/fraud/score
GET  /api/fraud/signals
```

and application metrics.

---

# 26. Compliance service

The compliance service performs deterministic checks such as:

* sanctions-name matching;
* risky-country checks;
* payment-policy evaluation.

Possible outcomes include:

```text
CLEAR
HOLD
```

The demo includes known sanctioned/risky values so that presenters can reliably trigger a compliance hold.

It also exposes representative policies such as:

```text
AML-001
PAY-007
KYC-003
```

---

# 27. Payments service

The payments service orchestrates:

```text
payment request
      │
      ├── fraud decision
      │
      ├── compliance decision
      │
      └── cache interaction
```

Representative results include:

```text
ACCEPTED
PENDING_CHALLENGE
REJECTED
```

Examples:

* fraud `BLOCK` → rejected;
* compliance `HOLD` → rejected;
* fraud `CHALLENGE` → pending challenge;
* otherwise → accepted.

It exposes endpoints including:

```text
POST /api/payments
GET  /api/payments
GET  /api/payments/:id
GET  /api/cache-status
```

---

# 27.1 SRE failure injection

The payments service supports a deterministic failure path.

When invoked with:

```json
{
  "simulate": "error"
}
```

it emits the log signature:

```text
PAYMENT_UPSTREAM_FAILURE
```

and produces an HTTP failure.

This is intentionally used by the SRE scenario.

---

# 28. Telecom architecture

The telecom domain demonstrates a platform-native decomposition of telecom operations.

```text
Telco Portal
     │
     ├────► Subscriber Service
     │
     ├────► BSS Facade ───► Legacy Billing
     │
     └────► Telco MCP
                │
                ├────► Network Service
                ├────► Commercial Service
                ├────► Policy Service
                └────► Subscriber/BSS capabilities
```

The demo is intentionally OpenChoreo-native.

WSO2 API Manager and WSO2 Integrator are **not required by the default laptop runtime**.

They can be introduced when a target architecture requires capabilities such as:

* API gateway mediation;
* API product governance;
* API monetization;
* formal API lifecycle governance;
* enterprise integration;
* protocol mediation;
* orchestration beyond the local demonstration.

The point is not that OpenChoreo replaces those products.

The point is that this repository focuses specifically on the **application platform / platform engineering layer**.

---

# 29. Legacy BSS modernization

The telecom application includes a simulated legacy billing service.

The `telco-bss-facade` demonstrates the architectural pattern:

```text
modern REST/JSON experience
           ↓
       BSS facade
           ↓
 legacy billing interface
```

This gives the demo a legacy-modernization scenario without requiring an external telco environment.

---

# 30. Telecom MCP server

The `telco-mcp` Component exposes governed operational tools.

Requests require contextual headers including:

```text
X-Partner-Id
X-Correlation-ID
```

Representative tools include:

### `retrieveSubscriberServiceStatus`

Returns subscriber/service state.

### `inspectNetworkOutage`

Inspects network/outage information.

### `requestQualityOnDemand`

Orchestrates a QoD request across:

```text
commercial authorization
        ↓
policy evaluation
        ↓
network session
        ↓
commercial settlement
```

### `checkPartnerWallet`

Inspects commercial/wallet information.

### `evaluateTelcoPolicy`

Evaluates policy inputs such as:

* country;
* consent;
* data residency;
* requested action;
* SIM-swap age.

The MCP server therefore represents a governed action surface rather than giving an LLM unrestricted access to backend services.

---

# 31. MCP architecture

The repository uses MCP as an important separation between:

```text
AI reasoning
```

and:

```text
business/platform capabilities
```

The Financial Operations Agent can discover tools from several MCP servers at runtime.

---

# 31.1 Customer MCP

Representative tools:

```text
get_customer_profile
list_customer_accounts
get_account
```

---

# 31.2 Risk MCP

Representative tools:

```text
score_transaction
get_fraud_signals
explain_risk_controls
```

---

# 31.3 Compliance MCP

Representative tools:

```text
check_payment_compliance
list_payment_policies
explain_control
```

---

# 31.4 OpenChoreo MCP

The Financial Operations Agent also connects to OpenChoreo MCP endpoints for:

* platform/control-plane context;
* observability context.

This allows the agent to combine business and operational information.

For example:

```text
"Why did this payment fail?"
           │
           ├── customer MCP
           ├── risk MCP
           ├── compliance MCP
           ├── OpenChoreo control MCP
           └── OpenChoreo observability MCP
```

---

# 32. AI and agent capabilities

The repository demonstrates several distinct AI/agent experiences.

It is important not to group all of them into a single "AI agent."

---

# 32.1 OpenChoreo SRE Agent / RCA Agent

The SRE Agent is part of the OpenChoreo observability capability.

It is intended to analyze incidents and operational telemetry.

The payments error alert is configured to allow:

```text
triggerAiRca: true
```

The demo flow is:

```text
injected payment failure
       ↓
PAYMENT_UPSTREAM_FAILURE
       ↓
OpenChoreo log alert
       ↓
incident
       ↓
SRE Agent
       ↓
RCA report
```

Run:

```bash
./demo.sh scenario sre
```

---

# 32.2 OpenChoreo FinOps Agent

The FinOps Agent combines observability/cost information with AI-assisted analysis.

The payments budget alert is configured with:

```text
triggerAiCostAnalysis: true
```

The local scenario intentionally manipulates demo OpenCost pricing so that the budget threshold can be crossed quickly.

Run:

```bash
./demo.sh scenario finops
```

This should be understood as **demo acceleration**, not as a claim that those artificial prices represent real cloud costs.

---

# 32.3 OpenChoreo Portal Assistant

The OpenChoreo portal can also run its AI assistant.

This is useful for interactive platform assistance within the portal experience.

The repository's AI-enablement script configures the assistant together with the SRE and FinOps agents.

---

# 32.4 Financial Operations Agent

The repository also contains its own application-level agent:

```text
financial-agent
```

This is different from the OpenChoreo SRE and FinOps agents.

Its purpose is to combine:

* customer information;
* account information;
* fraud/risk information;
* compliance information;
* OpenChoreo platform information;
* OpenChoreo observability information.

The agent dynamically discovers MCP tools and makes them available to the model.

---

## 32.4.1 Financial Agent modes

The Financial Operations Agent supports two modes.

### Scripted platform-safe mode

When no OpenAI API key is supplied, the agent can still call real MCP tools using a deterministic execution path.

This means the agent experience does not become completely unusable when external LLM credentials are unavailable.

### LLM tool-calling mode

When:

```text
OPENAI_API_KEY
```

is available, the agent can use the OpenAI Responses API and dynamically discovered MCP tools.

The repository currently defaults its agent configuration to the model defined by:

```text
OPENCHOREO_AGENT_MODEL
```

with the repository-tested default being:

```text
gpt-5.4
```

The model can be overridden without changing application code.

---

# 33. OpenAI API key configuration

> **Never commit an OpenAI API key to this repository.**

Do not put the key into:

* `README.md`;
* Git-tracked YAML;
* source code;
* Dockerfiles;
* container images;
* `.showcase.env`;
* `.showcase.env.example`.

Use an environment variable for the setup operation.

A convenient interactive approach that avoids placing the key directly in shell history is:

```bash
read -rsp "OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY
```

You can verify only that a value exists without printing the secret:

```bash
test -n "${OPENAI_API_KEY:-}" \
  && echo "OPENAI_API_KEY is set" \
  || echo "OPENAI_API_KEY is NOT set"
```

---

# 34. Enable the OpenChoreo AI agents

The simplest path is:

```bash
export OPENCHOREO_AGENT_MODEL="gpt-5.4"

./demo.sh ai
```

The underlying automation configures the OpenChoreo AI integrations.

After setup:

```bash
unset OPENAI_API_KEY
```

The setup stores the required credentials into the local platform secret-management path and synchronizes them to the relevant workloads.

---

# 34.1 What the AI setup configures

The repository's AI-enablement automation configures credentials for:

### SRE/RCA Agent

OpenBao path:

```text
secret/rca-llm-api-key
```

and an ExternalSecret used by the SRE/RCA deployment.

---

### FinOps Agent

OpenBao path:

```text
secret/finops-llm-api-key
```

and the FinOps Agent ExternalSecret.

---

### Portal Assistant

OpenBao path:

```text
secret/portal-assistant-llm-api-key
```

and the Portal Assistant ExternalSecret.

---

## 34.2 Components restarted/verified

The setup waits for deployments including:

```text
sre-agent
finops-agent
portal-assistant
```

It also configures the OpenCost/FinOps support required by the local environment.

---

# 35. Verify AI agent deployment

Check the observability-plane agents:

```bash
kubectl get pods -n openchoreo-observability-plane
```

More targeted:

```bash
kubectl get pods -n openchoreo-observability-plane \
  | grep -E 'sre-agent|finops-agent|opencost'
```

Check the control-plane assistant:

```bash
kubectl get pods -n openchoreo-control-plane \
  | grep -E 'portal-assistant|backstage'
```

Wait explicitly:

```bash
kubectl rollout status deployment/sre-agent \
  -n openchoreo-observability-plane
```

```bash
kubectl rollout status deployment/finops-agent \
  -n openchoreo-observability-plane
```

```bash
kubectl rollout status deployment/portal-assistant \
  -n openchoreo-control-plane
```

Inspect ExternalSecrets:

```bash
kubectl get externalsecret \
  -n openchoreo-observability-plane
```

```bash
kubectl get externalsecret \
  -n openchoreo-control-plane
```

Do **not** print the resulting Kubernetes Secret values during a shared demo.

---

# 36. Rotate/refresh the OpenAI API key

Set the replacement key:

```bash
read -rsp "New OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY
```

Run:

```bash
./scripts/refresh-ai-key.sh
```

Then remove it from the shell:

```bash
unset OPENAI_API_KEY
```

The refresh automation updates the local secret-management entries, forces ExternalSecret reconciliation, and restarts the affected agents.

---

# 37. AI-enabled qualified showcase

For the qualification path:

```bash
./scripts/showcase-freeze-rancher.sh
```

Then:

```bash
source .showcase.env
```

Set the OpenAI credential:

```bash
read -rsp "OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY
```

Select the model:

```bash
export OPENCHOREO_AGENT_MODEL="gpt-5.4"
```

Require AI readiness:

```bash
export SHOWCASE_ENABLE_AI=1
```

Prepare/verify:

```bash
./demo.sh prepare
```

After setup:

```bash
unset OPENAI_API_KEY
```

---

# 38. Financial Operations Agent and OpenAI

The custom Financial Operations Agent should be treated separately from:

```bash
./demo.sh ai
```

The `demo.sh ai` flow configures the **OpenChoreo SRE, FinOps, and Portal Assistant integrations**.

The repository-owned Financial Operations Agent:

```text
financial-agent
```

works without an OpenAI key using its deterministic MCP mode.

For LLM-based tool calling, it accepts an OpenAI key either from:

```text
OPENAI_API_KEY
```

in its process environment, or from the application's supported request field.

For production-style operation, use a platform-managed secret binding.

**Do not hard-code the key into the Workload manifest.**

---

# 38.1 One-shot Financial Agent LLM demo

First obtain the agent URL from:

```bash
./demo.sh status
```

Set it:

```bash
export FINANCIAL_AGENT_URL="http://..."
```

Set the key in your shell:

```bash
read -rsp "OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY
```

For a local one-off demo, create a protected temporary request file:

```bash
umask 077

python3 - <<'PY' > /tmp/openchoreo-financial-agent-request.json
import json
import os

print(json.dumps({
    "prompt": (
        "Investigate customer C001. "
        "Summarize the customer's accounts, applicable fraud and "
        "compliance controls, and any relevant current platform "
        "or observability information."
    ),
    "openaiApiKey": os.environ["OPENAI_API_KEY"]
}))
PY
```

Invoke the agent:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_AGENT_URL}/api/chat" \
  -H 'Content-Type: application/json' \
  --data-binary @/tmp/openchoreo-financial-agent-request.json \
  | python3 -m json.tool
```

Immediately remove the temporary file:

```bash
rm -f /tmp/openchoreo-financial-agent-request.json
unset OPENAI_API_KEY
```

This request-level key approach is convenient for a controlled local demo.

For a persistent/shared environment, inject the key through an approved OpenChoreo secret dependency instead.

---

# 39. Verify Financial Agent MCP discovery

Set the agent URL from `./demo.sh status`.

Then:

```bash
curl -sS \
  "${FINANCIAL_AGENT_URL}/api/mcp-status" \
  | python3 -m json.tool
```

This is particularly useful because it proves that the Financial Operations Agent is discovering actual MCP capabilities rather than answering from a hard-coded mock response.

---

# 40. Financial Agent without an OpenAI key

The fallback mode can be demonstrated without provider credentials:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_AGENT_URL}/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{
    "prompt":
      "Show the available information for customer C001 and explain the relevant risk and compliance controls."
  }' \
  | python3 -m json.tool
```

The response identifies the execution mode and includes tool/MCP evidence.

---

# 41. Installation requirements

Recommended local tools:

* Docker or Colima;
* k3d;
* kubectl;
* Helm;
* curl;
* Python 3;
* Bash.

A capable laptop is recommended because OpenChoreo includes multiple platform planes plus the demo estate.

A practical starting point is approximately:

```text
6 CPUs
16 GiB RAM
25 GiB free disk
```

Rancher and AI/observability capabilities add additional resource usage.

---

# 42. Apple Silicon / Colima example

A suitable Colima configuration is:

```bash
colima start \
  --vm-type=vz \
  --vz-rosetta \
  --cpu 6 \
  --memory 16
```

Verify Docker:

```bash
docker info
```

Verify Kubernetes tooling:

```bash
kubectl version --client
k3d version
helm version
```

---

# 43. Initial repository validation

Before provisioning:

```bash
chmod +x demo.sh
chmod +x scripts/*.sh
chmod +x apply_openchoreo_showcase_upgrade.sh
```

Run source-level validation:

```bash
./scripts/self-test.sh
```

The self-test checks repository invariants such as:

* shell syntax;
* JavaScript syntax;
* expected service/image cardinality;
* route assumptions;
* platform artifact presence;
* workflow definitions;
* Rancher support;
* operations support;
* telecom support;
* branding/path assumptions.

---

# 44. Start the complete demo

```bash
./demo.sh up
```

The bootstrap process roughly performs:

```text
preflight
   ↓
install/reuse OpenChoreo
   ↓
build/import demo images
   ↓
apply platform engineering artifacts
   ↓
create environments/pipeline
   ↓
create Projects and ProjectReleaseBindings
   ↓
create Resources
   ↓
create Components and Workloads
   ↓
wait for development ReleaseBindings
   ↓
apply Kubernetes ops RBAC
   ↓
start support infrastructure
   ↓
optionally configure Rancher
   ↓
seed deterministic business data
   ↓
verify
```

---

# 45. OpenChoreo installation

The repository installs/reuses:

```text
OpenChoreo v1.2.2
```

with the local quick-start environment and enables the supporting build and observability capabilities needed by the showcase.

The installer is designed to reuse an already-compatible local deployment when appropriate rather than blindly reinstalling everything.

---

# 46. Application bootstrap order

The application estate is created in a dependency-aware sequence.

Conceptually:

```text
customer foundations
risk foundations
compliance foundations
      ↓
domain MCP servers
      ↓
payments
      ↓
financial BFF
financial agent
      ↓
telecom foundation services
      ↓
telecom BSS/MCP/portal
      ↓
Kubernetes operations
      ↓
Platform Portal
```

The bootstrap then waits for the expected development ReleaseBindings to become ready.

---

# 47. Local image model

For deterministic laptop execution, the repository builds demo service images locally and imports them into the k3d container runtime.

This is different from demonstrating a remote production CI/CD registry.

The platform artifacts still expose the OpenChoreo release/build abstractions, but the local demo optimizes for:

* reproducibility;
* offline-ish repeatability;
* fast clean-room resets;
* removal of registry dependencies.

---

# 48. Main demo command interface

```bash
./demo.sh up
./demo.sh reset
./demo.sh verify
./demo.sh status
./demo.sh capabilities
./demo.sh readiness
./demo.sh prepare
./demo.sh ai
./demo.sh rancher
./demo.sh scenario <name>
./demo.sh stop
./demo.sh start
./demo.sh destroy
```

---

# 49. `demo.sh up`

Provision/start the platform and demo.

```bash
./demo.sh up
```

---

# 50. `demo.sh status`

Display current platform/application state and useful URLs.

```bash
./demo.sh status
```

Use this before raw `curl` scenarios to obtain the current external routes.

---

# 51. `demo.sh verify`

Verify the running platform.

```bash
./demo.sh verify
```

---

# 52. `demo.sh reset`

Perform a deterministic clean-room rebuild.

```bash
./demo.sh reset
```

For evidence:

```bash
./demo.sh reset \
  | tee /tmp/openchoreo-platform-clean-room.log
```

The clean-room process verifies that the demo can be reconstructed rather than relying on undocumented residual cluster state.

---

# 53. `demo.sh capabilities`

Enumerate live showcase capability evidence.

```bash
./demo.sh capabilities
```

This is particularly useful before a customer demonstration.

---

# 54. `demo.sh readiness`

Perform broader showcase-readiness checks.

```bash
./demo.sh readiness
```

This combines repository and runtime evidence.

---

# 55. `demo.sh prepare`

Prepare the environment according to the qualified showcase settings.

```bash
./demo.sh prepare
```

---

# 56. `demo.sh ai`

Configure OpenChoreo's AI agent integrations.

```bash
export OPENAI_API_KEY="..."
export OPENCHOREO_AGENT_MODEL="gpt-5.4"

./demo.sh ai

unset OPENAI_API_KEY
```

Prefer the `read -s` approach shown earlier rather than typing the actual key directly into shell history.

---

# 57. `demo.sh rancher`

Inspect/start/configure Rancher integration.

```bash
./demo.sh rancher
```

---

# 58. `demo.sh stop` / `start`

Stop:

```bash
./demo.sh stop
```

Start:

```bash
./demo.sh start
```

---

# 59. `demo.sh destroy`

Destroy the local demo resources.

```bash
./demo.sh destroy
```

Use this only when you really want to remove the local demo environment.

---

# 60. Demo cookbook

The following sections provide both high-level scenario commands and lower-level `curl`/`kubectl` evidence.

---

# 61. Cookbook — establish current URLs

Always begin with:

```bash
./demo.sh status
```

The OpenChoreo portal is normally available through the local OpenChoreo route, typically:

```text
http://openchoreo.localhost:8080
```

Application URLs are generated through OpenChoreo gateway routing.

Do not hard-code them in long-lived scripts if the environment can provide them dynamically.

For cookbook examples, export values returned by `./demo.sh status`:

```bash
export FINANCIAL_BFF_URL="http://..."
export FINANCIAL_AGENT_URL="http://..."
export TELCO_PORTAL_URL="http://..."
export K8S_OPS_URL="http://..."
```

---

# 62. Cookbook — OpenChoreo inventory

First discover the installed OpenChoreo resources:

```bash
kubectl api-resources \
  | grep -Ei 'openchoreo|projecttype|componenttype|trait|resource|workflow'
```

List the primary namespace:

```bash
kubectl get namespace platform-demo
```

List Projects:

```bash
kubectl get project -n platform-demo
```

List Components:

```bash
kubectl get component -n platform-demo
```

List Workloads:

```bash
kubectl get workload -n platform-demo
```

List ProjectReleaseBindings:

```bash
kubectl get projectreleasebinding -n platform-demo
```

List ReleaseBindings:

```bash
kubectl get releasebinding -n platform-demo
```

List ComponentReleases:

```bash
kubectl get componentrelease -n platform-demo
```

List Resources:

```bash
kubectl get resource -n platform-demo
```

List ResourceReleaseBindings:

```bash
kubectl get resourcereleasebinding -n platform-demo
```

---

# 63. Cookbook — inspect all custom golden-path artifacts

Regulated ProjectType:

```bash
kubectl get clusterprojecttype regulated-platform -o yaml
```

Regulated ComponentType:

```bash
kubectl get clustercomponenttype regulated-service -o yaml
```

Hardening Trait:

```bash
kubectl get clustertrait bank-runtime-hardening -o yaml
```

Valkey ResourceType:

```bash
kubectl get clusterresourcetype platform-valkey-cache -o yaml
```

Regulated release workflow:

```bash
kubectl get clusterworkflow regulated-release-gate -o yaml
```

Namespaced policy workflow:

```bash
kubectl get workflow platform-policy-gate \
  -n platform-demo \
  -o yaml
```

---

# 64. Cookbook — environment and pipeline evidence

```bash
kubectl get environment -n platform-demo
```

```bash
kubectl get deploymentpipeline -n platform-demo
```

Inspect the standard pipeline:

```bash
kubectl get deploymentpipeline platform-standard \
  -n platform-demo \
  -o yaml
```

---

# 65. Cookbook — inspect the regulated project cells

Find generated platform namespaces:

```bash
kubectl get namespaces \
  --show-labels \
  | grep platform-demo
```

Inspect quotas globally:

```bash
kubectl get resourcequota -A
```

Inspect LimitRanges:

```bash
kubectl get limitrange -A
```

Inspect NetworkPolicies:

```bash
kubectl get networkpolicy -A
```

Look specifically for demo resources:

```bash
kubectl get resourcequota,limitrange,networkpolicy -A \
  | grep platform-demo
```

---

# 66. Cookbook — verify data-plane ProjectType permissions

Inspect the associated RBAC:

```bash
kubectl get clusterrole \
  platform-demo-projecttype-dataplane-applier \
  -o yaml
```

Then use Kubernetes authorization checks for the OpenChoreo data-plane service account if troubleshooting ProjectType materialization.

The repository bootstrap already performs these permission checks automatically.

---

# 67. Cookbook — verify regulated payments golden path

Inspect the OpenChoreo Component:

```bash
kubectl get component payments-service \
  -n platform-demo \
  -o yaml
```

You should see that the Component uses the regulated service ComponentType rather than the generic deployment path.

Also run the repository's dedicated verifier:

```bash
./scripts/verify-platform-engineering.sh
```

This is the preferred automated proof because generated Kubernetes resource names can vary.

---

# 68. Cookbook — inspect generated payments runtime

Locate payments resources:

```bash
kubectl get deployment,pod,service,pdb -A \
  | grep payments
```

Inspect the generated Deployment once its namespace/name is known:

```bash
kubectl -n <payments-namespace> \
  get deployment <payments-deployment> \
  -o yaml
```

Look for:

```yaml
automountServiceAccountToken: false
```

and:

```yaml
seccompProfile:
  type: RuntimeDefault
```

and:

```yaml
allowPrivilegeEscalation: false
```

and:

```yaml
capabilities:
  drop:
    - ALL
```

Inspect PDBs:

```bash
kubectl get pdb -A \
  | grep payments
```

This is direct evidence that the Trait reached the generated Kubernetes runtime.

---

# 69. Cookbook — inspect managed Valkey

OpenChoreo resource:

```bash
kubectl get resource payment-idempotency-cache \
  -n platform-demo \
  -o yaml
```

Bindings:

```bash
kubectl get resourcereleasebinding \
  -n platform-demo
```

Kubernetes runtime:

```bash
kubectl get statefulset,service,secret,networkpolicy -A \
  | grep -i valkey
```

Do not print the Secret value during a shared demonstration.

---

# 70. Cookbook — normal financial payment

Use the high-level scenario:

```bash
./demo.sh scenario payment
```

Or invoke the BFF directly:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_BFF_URL}/api/pay" \
  -H 'Content-Type: application/json' \
  -d '{
    "transactionId": "TX-DEMO-NORMAL",
    "customerId": "C001",
    "amount": 1250,
    "currency": "BRL",
    "beneficiaryName": "Loja Exemplo SA",
    "beneficiaryCountry": "BR",
    "deviceId": "device-maria-1",
    "channel": "WEB"
  }' \
  | python3 -m json.tool
```

This demonstrates a normal fraud/compliance/payment path.

---

# 71. Cookbook — fraud challenge

High-level:

```bash
./demo.sh scenario challenge
```

Raw:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_BFF_URL}/api/pay" \
  -H 'Content-Type: application/json' \
  -d '{
    "transactionId": "TX-DEMO-CHALLENGE",
    "customerId": "C001",
    "amount": 25000,
    "currency": "BRL",
    "beneficiaryName": "Novo Beneficiario",
    "beneficiaryCountry": "BR",
    "deviceId": "new-device-demo",
    "channel": "WEB"
  }' \
  | python3 -m json.tool
```

Expected business behavior is the challenge path.

---

# 72. Cookbook — compliance hold

High-level:

```bash
./demo.sh scenario hold
```

Raw:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_BFF_URL}/api/pay" \
  -H 'Content-Type: application/json' \
  -d '{
    "transactionId": "TX-DEMO-HOLD",
    "customerId": "C001",
    "amount": 750,
    "currency": "BRL",
    "beneficiaryName": "Test Sanctioned Person",
    "beneficiaryCountry": "BR",
    "deviceId": "device-maria-1",
    "channel": "WEB"
  }' \
  | python3 -m json.tool
```

The sanctioned beneficiary intentionally triggers the compliance control.

---

# 73. Cookbook — fraud block

High-level:

```bash
./demo.sh scenario block
```

Raw:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_BFF_URL}/api/pay" \
  -H 'Content-Type: application/json' \
  -d '{
    "transactionId": "TX-DEMO-BLOCK",
    "customerId": "C001",
    "amount": 80000,
    "currency": "BRL",
    "beneficiaryName": "Treasury Demo",
    "beneficiaryCountry": "BR",
    "deviceId": "new-device-demo",
    "channel": "API"
  }' \
  | python3 -m json.tool
```

This intentionally accumulates enough deterministic risk to exercise the block path.

---

# 74. Cookbook — Financial Operations Agent

Check discovered MCP tools:

```bash
curl -sS \
  "${FINANCIAL_AGENT_URL}/api/mcp-status" \
  | python3 -m json.tool
```

Ask a business question without OpenAI credentials:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_AGENT_URL}/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{
    "prompt":
      "Investigate customer C001 and summarize the customer, accounts, fraud controls and compliance controls."
  }' \
  | python3 -m json.tool
```

Ask an operational question:

```bash
curl -sS \
  -X POST \
  "${FINANCIAL_AGENT_URL}/api/chat" \
  -H 'Content-Type: application/json' \
  -d '{
    "prompt":
      "Investigate recent payment failures and include any relevant platform alerts or incidents."
  }' \
  | python3 -m json.tool
```

With an OpenAI key, follow the protected one-shot procedure documented earlier.

---

# 75. Cookbook — telecom QoD request

High-level:

```bash
./demo.sh scenario qod
```

Raw:

```bash
curl -sS \
  -X POST \
  "${TELCO_PORTAL_URL}/api/qod" \
  -H 'Content-Type: application/json' \
  -d '{
    "subscriberId": "5511999999999",
    "profile": "LOW_LATENCY",
    "durationSeconds": 900,
    "country": "BR"
  }' \
  | python3 -m json.tool
```

This exercises the governed telecom orchestration path.

---

# 76. Cookbook — telecom data-residency policy

High-level:

```bash
./demo.sh scenario residency
```

Raw:

```bash
curl -sS \
  -X POST \
  "${TELCO_PORTAL_URL}/api/policy" \
  -H 'Content-Type: application/json' \
  -d '{
    "partnerId": "partner-alpha",
    "country": "BR",
    "dataResidency": "OUTSIDE_BR",
    "consent": "ACTIVE",
    "action": "LOCATION"
  }' \
  | python3 -m json.tool
```

This demonstrates an explicit policy decision instead of allowing the agent/workflow to execute every request blindly.

---

# 77. Cookbook — legacy billing

High-level:

```bash
./demo.sh scenario legacy
```

Raw:

```bash
curl -sS \
  "${TELCO_PORTAL_URL}/api/billing/5511999999999" \
  | python3 -m json.tool
```

This demonstrates the modern-experience-to-legacy-BSS path.

---

# 78. Cookbook — SRE / RCA Agent

Ensure AI integrations are configured first:

```bash
./demo.sh ai
```

Then run:

```bash
./demo.sh scenario sre
```

The scenario injects a failure equivalent to:

```json
{
  "transactionId": "TX-SRE-FAIL",
  "customerId": "C001",
  "amount": 999.90,
  "currency": "BRL",
  "beneficiaryName": "Failure Lab",
  "beneficiaryCountry": "BR",
  "simulate": "error"
}
```

Observe webhook evidence:

```bash
tail -f runtime/alerts.ndjson
```

Inspect SRE Agent logs if required:

```bash
kubectl logs \
  -n openchoreo-observability-plane \
  deployment/sre-agent \
  --tail=200
```

Inspect its rollout:

```bash
kubectl rollout status \
  deployment/sre-agent \
  -n openchoreo-observability-plane
```

Use the OpenChoreo portal to inspect:

* alert;
* incident;
* RCA evidence.

---

# 79. Cookbook — FinOps Agent

Ensure AI is enabled:

```bash
./demo.sh ai
```

Run:

```bash
./demo.sh scenario finops
```

Inspect supporting workloads:

```bash
kubectl get pods \
  -n openchoreo-observability-plane \
  | grep -E 'finops-agent|opencost|prometheus'
```

Inspect FinOps Agent logs:

```bash
kubectl logs \
  -n openchoreo-observability-plane \
  deployment/finops-agent \
  --tail=200
```

The scenario intentionally adjusts local OpenCost pricing so a budget condition can be demonstrated quickly.

After the demo, treat those values as demonstration data, not real production costing.

---

# 80. Cookbook — Kubernetes self-healing

Run:

```bash
./demo.sh scenario self-heal
```

The scenario identifies a payments Pod, deletes it through Kubernetes, and demonstrates that the desired state recreates the workload.

Manual inspection:

```bash
kubectl get pods -A \
  | grep payments
```

Watch:

```bash
kubectl get pods -A -w \
  | grep payments
```

The key platform story is:

```text
Pod disappears
    ↓
Kubernetes reconciles Deployment
    ↓
new Pod appears
    ↓
OpenChoreo application remains represented by desired state
```

---

# 81. Cookbook — Kubernetes operations proof

Run:

```bash
./scripts/k8s-proof.sh
```

Also inspect:

```bash
kubectl get deployment,pod,service,httproute,networkpolicy -A
```

This proves that OpenChoreo abstractions ultimately correspond to real Kubernetes resources.

---

# 82. Cookbook — platform engineering scenario

Run:

```bash
./demo.sh scenario platform-engineering
```

Then:

```bash
./scripts/verify-platform-engineering.sh
```

Use this scenario to demonstrate:

* ProjectType;
* ComponentType;
* Trait;
* managed Resource;
* policy workflow;
* authorization;
* generated Kubernetes controls.

---

# 83. Cookbook — promotion

Run the complete scenario:

```bash
./demo.sh scenario promotion
```

This demonstrates:

1. development release;
2. promotion to staging;
3. same immutable ComponentRelease;
4. production release gate;
5. promotion to production.

Manual promotion helper examples:

```bash
./scripts/promote.sh staging financial
```

For production governance, run the gate first:

```bash
./scripts/run-regulated-release-gate.sh pass production
```

Then promote according to the demo procedure.

The repository promotion helper also supports telecom/all scopes where appropriate.

---

# 84. Cookbook — compare release identity across environments

List releases:

```bash
kubectl get componentrelease \
  -n platform-demo
```

List bindings:

```bash
kubectl get releasebinding \
  -n platform-demo
```

Inspect a selected binding:

```bash
kubectl get releasebinding <name> \
  -n platform-demo \
  -o yaml
```

The evidence to look for is that staging/production point to the already-created immutable release rather than an independently rebuilt artifact.

---

# 85. Cookbook — OpenChoreo authorization

Inspect namespaced role:

```bash
kubectl get authzrole \
  -n platform-demo
```

```bash
kubectl get authzrole platform-auditor \
  -n platform-demo \
  -o yaml
```

Inspect namespaced bindings:

```bash
kubectl get authzrolebinding \
  -n platform-demo
```

Inspect cluster bindings:

```bash
kubectl get clusterauthzrolebinding
```

Use the YAML output to demonstrate the explicit production condition on developer access.

---

# 86. Cookbook — notification channels

Discover:

```bash
kubectl api-resources \
  | grep -i notification
```

Then list the OpenChoreo observability notification-channel objects in:

```text
platform-demo
```

The expected logical channels are:

```text
platform-webhook-development
platform-webhook-staging
platform-webhook-production
```

Observe received events:

```bash
tail -f runtime/alerts.ndjson
```

---

# 87. Platform Portal

`platform-portal` is a repository-owned experience intended to unify the showcase.

It should not be confused with the native OpenChoreo developer portal.

Recommended positioning:

### OpenChoreo portal

Use for:

* Projects;
* Components;
* releases;
* observability;
* platform abstractions;
* agent/assistant experiences.

### Platform Portal

Use for:

* scenario launching;
* business-oriented storytelling;
* demo navigation;
* consolidated showcase context.

### Kubernetes operations console / Rancher

Use for:

* runtime infrastructure proof;
* Pod/Deployment evidence;
* reconciliation;
* cluster-level operations.

---

# 88. Kubernetes operations console

The `k8s-ops-console` is deliberately backed by the real Kubernetes API.

It is not just a static mock dashboard.

Use it to show:

* Pods;
* workloads;
* runtime state;
* selected operational actions;
* reconciliation behavior;
* OpenChoreo-to-Kubernetes mapping.

The permissions are intentionally constrained through the custom Kubernetes RBAC described earlier.

---

# 89. Rancher integration

Rancher is optional and runs separately from the OpenChoreo platform components.

Typical URL:

```text
https://localhost:8444
```

The repository includes automation to:

* start Rancher;
* obtain bootstrap credentials;
* import/register the existing k3d cluster;
* verify connectivity.

Inspect Rancher container status:

```bash
docker ps \
  | grep platform-rancher
```

Logs:

```bash
docker logs platform-rancher \
  --tail 100
```

Inspect Rancher-created cluster resources:

```bash
kubectl get pods -n cattle-system
```

---

# 90. Strict Rancher mode

The ordinary demo can continue when Rancher is unavailable because Rancher is not required by OpenChoreo itself.

For a qualified showcase where Rancher is mandatory:

```bash
RANCHER_REQUIRED=1 ./demo.sh reset
```

The strict showcase configuration can also require Rancher readiness through `.showcase.env`.

---

# 91. Rancher image freezing

For reproducible showcase qualification:

```bash
./scripts/showcase-freeze-rancher.sh
```

This resolves/pins the Rancher image more deterministically for the qualified environment.

The normal default can otherwise follow the configured Rancher image/tag.

---

# 92. Showcase configuration

The repository provides:

```text
.showcase.env.example
```

Representative flags include concepts such as:

```text
ENABLE_RANCHER
RANCHER_REQUIRED
SHOWCASE_STRICT
SHOWCASE_REQUIRE_RANCHER
OPENCHOREO_CLUSTER_NAME
SHOWCASE_ENABLE_AI
SHOWCASE_REQUIRE_AI
```

Do not put API secrets into this tracked configuration.

---

# 93. Showcase qualification sequence

Without AI:

```bash
./scripts/showcase-freeze-rancher.sh
source .showcase.env
./demo.sh reset
./demo.sh readiness
```

With AI:

```bash
./scripts/showcase-freeze-rancher.sh
source .showcase.env

read -rsp "OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY

export OPENCHOREO_AGENT_MODEL="gpt-5.4"
export SHOWCASE_ENABLE_AI=1

./demo.sh reset
./demo.sh prepare
./demo.sh readiness

unset OPENAI_API_KEY
```

---

# 94. Clean-room verification

One of the strongest properties of the repository is the clean-room path.

Run:

```bash
./demo.sh reset \
  | tee /tmp/openchoreo-platform-clean-room.log
```

The verifier checks live state including the expected:

* Projects;
* ProjectReleaseBindings;
* Components;
* development ReleaseBindings;
* local images;
* generated Kubernetes Deployments;
* Valkey StatefulSet;
* external application routes;
* financial payment path;
* telecom path;
* Kubernetes API access;
* observability rendering.

Successful runs print explicit clean-room success markers.

This is valuable because it tests **reproducibility from desired state**, not just the current machine's accumulated state.

---

# 95. Validation layers

The repository uses several levels of validation.

## Source validation

```bash
./scripts/self-test.sh
```

Checks repository-level invariants.

## Runtime verification

```bash
./demo.sh verify
```

Checks an existing deployment.

## Platform-engineering verification

```bash
./scripts/verify-platform-engineering.sh
```

Checks the custom platform extensions.

## Kubernetes proof

```bash
./scripts/k8s-proof.sh
```

Shows runtime Kubernetes evidence.

## Capability verification

```bash
./demo.sh capabilities
```

Checks presence/readiness of major showcase capabilities.

## Showcase readiness

```bash
./demo.sh readiness
```

Combines the evidence required for a presentable environment.

## Clean-room verification

```bash
./demo.sh reset
```

Rebuilds and proves the environment from scratch.

---

# 96. Useful Kubernetes operational commands

Cluster:

```bash
kubectl cluster-info
```

Namespaces:

```bash
kubectl get namespaces
```

OpenChoreo planes:

```bash
kubectl get pods -A \
  | grep openchoreo
```

All demo application workloads:

```bash
kubectl get deployment,statefulset,pod -A \
  | grep -E 'platform-demo|payments|financial|telco|customer|risk|compliance'
```

HTTP routes:

```bash
kubectl get httproute -A
```

Network policies:

```bash
kubectl get networkpolicy -A
```

Quotas:

```bash
kubectl get resourcequota -A
```

Events:

```bash
kubectl get events -A \
  --sort-by=.lastTimestamp \
  | tail -100
```

---

# 97. Debug a failing application

Find Pod:

```bash
kubectl get pods -A \
  | grep <component>
```

Describe:

```bash
kubectl -n <namespace> \
  describe pod <pod>
```

Logs:

```bash
kubectl -n <namespace> \
  logs <pod> \
  --tail=200
```

Deployment:

```bash
kubectl -n <namespace> \
  describe deployment <deployment>
```

Events:

```bash
kubectl -n <namespace> \
  get events \
  --sort-by=.lastTimestamp
```

---

# 98. Debug OpenChoreo rendering

Inspect the application abstractions:

```bash
kubectl get component -n platform-demo
kubectl get workload -n platform-demo
kubectl get componentrelease -n platform-demo
kubectl get releasebinding -n platform-demo
```

Then inspect the rendered artifact:

```bash
kubectl get renderedrelease -n platform-demo
```

If needed:

```bash
kubectl get renderedrelease <name> \
  -n platform-demo \
  -o yaml
```

This helps determine whether an issue originates in:

```text
Component/Workload desired state
```

or:

```text
generated Kubernetes runtime
```

---

# 99. Debug managed Resource provisioning

OpenChoreo:

```bash
kubectl get resource -n platform-demo
kubectl get resourcereleasebinding -n platform-demo
```

Kubernetes:

```bash
kubectl get statefulset,service,secret,networkpolicy -A \
  | grep -i valkey
```

Then inspect the StatefulSet:

```bash
kubectl -n <namespace> \
  describe statefulset <valkey-statefulset>
```

---

# 100. Debug AI agent setup

Check SRE:

```bash
kubectl get deployment/sre-agent \
  -n openchoreo-observability-plane
```

```bash
kubectl logs deployment/sre-agent \
  -n openchoreo-observability-plane \
  --tail=200
```

Check FinOps:

```bash
kubectl get deployment/finops-agent \
  -n openchoreo-observability-plane
```

```bash
kubectl logs deployment/finops-agent \
  -n openchoreo-observability-plane \
  --tail=200
```

Check Portal Assistant:

```bash
kubectl get deployment/portal-assistant \
  -n openchoreo-control-plane
```

```bash
kubectl logs deployment/portal-assistant \
  -n openchoreo-control-plane \
  --tail=200
```

Check ExternalSecret reconciliation:

```bash
kubectl get externalsecret -A
```

If an API key has changed:

```bash
./scripts/refresh-ai-key.sh
```

---

# 101. Debug Financial Operations Agent

Check Component:

```bash
kubectl get component financial-agent \
  -n platform-demo \
  -o yaml
```

Find runtime Pod:

```bash
kubectl get pods -A \
  | grep financial-agent
```

Logs:

```bash
kubectl -n <namespace> \
  logs <financial-agent-pod> \
  --tail=200
```

Check MCP status through the public endpoint:

```bash
curl -sS \
  "${FINANCIAL_AGENT_URL}/api/mcp-status" \
  | python3 -m json.tool
```

A useful debugging distinction is:

```text
agent reachable?
      ↓
MCP endpoints reachable?
      ↓
tools discovered?
      ↓
OpenAI key/model valid?
      ↓
tool calls succeeding?
```

Do not start by assuming every agent failure is an LLM problem.

---

# 102. Script inventory

The scripts are part of the productized demo experience and should be considered first-class repository capabilities.

## Installation/bootstrap

```text
preflight.sh
install-openchoreo.sh
build-images.sh
ensure-app-images.sh
bootstrap-all.sh
bootstrap-data.sh
bootstrap-telco-data.sh
seed-data.sh
apply-ops-rbac.sh
```

## Lifecycle and environment operations

```text
doctor.sh
status.sh
reset-from-scratch.sh
teardown-demo.sh
rancher.sh
start-webhook-receiver.sh
stop-webhook-receiver.sh
```

## Validation

```text
self-test.sh
validate-local-services.sh
verify-clean-room.sh
verify-platform-engineering.sh
k8s-proof.sh
showcase-capabilities.sh
showcase-readiness.sh
```

## Policy, release, and promotion

```text
promote.sh
run-policy-gate.sh
run-regulated-release-gate.sh
```

## Scenarios

```text
scenario.sh
scenario-sre.sh
scenario-finops.sh
scenario-platform-engineering.sh
scenario-promotion.sh
```

## AI

```text
enable-ai-agents.sh
refresh-ai-key.sh
```

## Showcase qualification

```text
showcase-freeze-rancher.sh
showcase-prepare.sh
showcase-readiness.sh
```

## Shared script utilities

```text
lib.sh
```

---

# 103. Root upgrade helper

The repository also retains:

```text
apply_openchoreo_showcase_upgrade.sh
```

This is an upgrade/migration-style helper for applying the extended showcase platform-engineering content to an earlier repository/environment state.

The current `main` branch already contains the resulting artifacts.

For a fresh deployment from current `main`, prefer the documented `demo.sh` lifecycle rather than treating the upgrade helper as the normal bootstrap path.

---

# 104. Documentation inventory

Additional repository documentation provides specialized detail.

## `docs/ARCHITECTURE.md`

Deep architecture description.

## `docs/DEMO-RUNBOOK.md`

Presenter/demo execution guidance.

## `docs/RANCHER.md`

Rancher architecture and operations.

## `docs/SHOWCASE-CAPABILITY-MAP.md`

Maps showcase claims to concrete implementation/evidence.

## `docs/SHOWCASE-RUNBOOK.md`

Qualified showcase execution.

## `docs/TELCO-OPENCHOREO-ADAPTATION.md`

Explains the OpenChoreo-native telecom adaptation and product boundaries.

## `docs/TROUBLESHOOTING.md`

Known failure/recovery guidance.

## `docs/VALIDATION.md`

Validation and clean-room verification details.

---

# 105. Recommended demonstration order

A strong end-to-end presentation is:

## Step 1 — establish the platform

```bash
./demo.sh status
./demo.sh capabilities
```

Show:

* OpenChoreo portal;
* Projects;
* Components;
* environments.

---

## Step 2 — show the hidden platform engineering

```bash
kubectl get clusterprojecttype regulated-platform -o yaml
kubectl get clustercomponenttype regulated-service -o yaml
kubectl get clustertrait bank-runtime-hardening -o yaml
kubectl get clusterresourcetype platform-valkey-cache -o yaml
```

Explain:

```text
platform team builds reusable abstractions
developers consume them
```

---

## Step 3 — show generated Kubernetes policy

```bash
./scripts/verify-platform-engineering.sh
```

Then:

```bash
kubectl get resourcequota,limitrange,networkpolicy,pdb -A
```

---

## Step 4 — execute business payment paths

```bash
./demo.sh scenario payment
./demo.sh scenario challenge
./demo.sh scenario hold
./demo.sh scenario block
```

---

## Step 5 — show the Financial Operations Agent

```bash
curl -sS "${FINANCIAL_AGENT_URL}/api/mcp-status" \
  | python3 -m json.tool
```

Then ask an agent question.

Explain that MCP provides governed business/platform tools.

---

## Step 6 — show observability and SRE Agent

```bash
./demo.sh scenario sre
```

Show:

```text
failure
→ log
→ alert
→ incident
→ AI RCA
```

---

## Step 7 — show FinOps

```bash
./demo.sh scenario finops
```

Show:

```text
budget signal
→ alert
→ incident
→ cost analysis
```

---

## Step 8 — show governance

```bash
./demo.sh scenario regulated-gate-fail
```

Then:

```bash
./demo.sh scenario regulated-gate-pass
```

Demonstrate that the platform supports both denial and approval.

---

## Step 9 — show immutable promotion

```bash
./demo.sh scenario promotion
```

Show the same ComponentRelease moving through environments.

---

## Step 10 — show real Kubernetes reconciliation

```bash
./demo.sh scenario self-heal
```

Use the Kubernetes operations console and/or Rancher as complementary evidence.

---

## Step 11 — show telecom governed actions

```bash
./demo.sh scenario qod
./demo.sh scenario residency
./demo.sh scenario legacy
```

---

# 106. Platform engineering story in one diagram

```text
                  PLATFORM TEAM
                       │
                       │ defines
                       ▼
       ┌──────────────────────────────────┐
       │ Regulated ProjectType            │
       │ Regulated ComponentType          │
       │ Hardening Trait                  │
       │ Managed ResourceType             │
       │ Workflows / release policies     │
       │ Authorization                    │
       │ Observability policies           │
       └────────────────┬─────────────────┘
                        │
                        │ consumed by
                        ▼
                 APPLICATION TEAMS
                        │
                        ▼
       ┌──────────────────────────────────┐
       │ Projects                         │
       │ Components                       │
       │ Workloads                        │
       │ Resources                        │
       │ Releases                         │
       └────────────────┬─────────────────┘
                        │
                        │ rendered by OpenChoreo
                        ▼
       ┌──────────────────────────────────┐
       │ Kubernetes                       │
       │                                  │
       │ Namespaces                       │
       │ Deployments                      │
       │ Services                         │
       │ HTTPRoutes                       │
       │ NetworkPolicies                  │
       │ ResourceQuotas                   │
       │ LimitRanges                      │
       │ PDBs                             │
       │ StatefulSets                     │
       └──────────────────────────────────┘
```

---

# 107. Agentic operations story in one diagram

```text
                             USER / OPERATOR
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
          Financial Operations Agent      OpenChoreo Portal
                    │                             │
                    │                             ▼
                    │                      Portal Assistant
                    │
          ┌─────────┼───────────────┐
          │         │               │
          ▼         ▼               ▼
     Customer     Risk         Compliance
       MCP         MCP             MCP
          │         │               │
          └─────────┼───────────────┘
                    │
                    ├────────► OpenChoreo Control MCP
                    └────────► OpenChoreo Observability MCP


Application telemetry
        │
        ├──── error alert ────► incident ────► SRE Agent / RCA
        │
        └──── budget alert ───► incident ────► FinOps Agent
```

---

# 108. Security and governance caveats

This repository is a sophisticated local showcase, but it is still a **demo environment**.

Production deployments should revisit at least:

* identity integration;
* TLS/certificates;
* external secrets;
* secret rotation;
* managed infrastructure;
* resource sizing;
* high availability;
* persistent storage;
* backup/restore;
* network topology;
* registry strategy;
* admission control;
* vulnerability scanning;
* SBOM/provenance;
* production OAuth clients;
* audit retention;
* SIEM integration;
* cost-data sources;
* AI governance;
* model/provider governance;
* data-loss prevention;
* PII handling;
* MCP authorization;
* tool-level authorization;
* OpenAI/API-provider connectivity;
* change-management integration.

---

# 109. AI security recommendations

For shared or production-like environments:

* never place `OPENAI_API_KEY` in Git;
* never hard-code it in a Component;
* never bake it into an image;
* use an approved secret store;
* keep model credentials separate by workload where possible;
* rotate keys;
* restrict outbound model-provider access;
* audit agent tool execution;
* distinguish read tools from mutating tools;
* apply least privilege to MCP services;
* avoid exposing privileged Kubernetes credentials to general-purpose agents;
* classify which telemetry/data may leave the environment;
* ensure customer/PII policies permit external LLM processing.

The local demo's OpenBao + ExternalSecret integration is the right architectural direction for the built-in agents, even though enterprise deployments may use a different secrets platform.

---

# 110. What the demo does not claim

The repository should not be interpreted as claiming that:

* Rancher is part of OpenChoreo;
* the custom Platform Portal replaces the OpenChoreo portal;
* the deterministic banking rules are production fraud/compliance models;
* the local Valkey StatefulSet is a production managed-cache architecture;
* artificial FinOps prices are real cloud-cost calculations;
* MCP alone provides all necessary enterprise API governance;
* OpenChoreo replaces WSO2 API Manager;
* OpenChoreo replaces WSO2 Integrator;
* a local k3d topology is a production OpenChoreo topology.

Instead, the repository demonstrates **patterns and platform capabilities** in a reproducible laptop environment.

---

# 111. Capability checklist

The current repository demonstrates:

* [x] Local OpenChoreo installation
* [x] Build capability
* [x] Observability capability
* [x] Workflow capability
* [x] Multi-project platform
* [x] Development environment
* [x] Staging environment
* [x] Production environment
* [x] Deployment pipeline
* [x] ProjectReleaseBindings
* [x] Components
* [x] Workloads
* [x] ComponentReleases
* [x] ReleaseBindings
* [x] RenderedReleases
* [x] Cross-project dependencies
* [x] Custom ClusterProjectType
* [x] Environment-specific quotas
* [x] LimitRanges
* [x] Default-deny networking
* [x] Project metadata/classification
* [x] Custom ClusterComponentType
* [x] Custom ClusterTrait
* [x] Runtime security hardening
* [x] PodDisruptionBudget creation
* [x] Managed ClusterResourceType
* [x] Resource
* [x] ResourceReleaseBindings
* [x] Application resource binding
* [x] OpenChoreo authorization
* [x] Kubernetes RBAC
* [x] Namespaced Workflow
* [x] ClusterWorkflow
* [x] Positive policy-gate path
* [x] Negative policy-gate path
* [x] Production approval evidence
* [x] Immutable promotion
* [x] Log alerts
* [x] Metric alerts
* [x] Budget alerts
* [x] Notification channels
* [x] Webhook alert evidence
* [x] Incident generation
* [x] AI RCA trigger
* [x] AI FinOps trigger
* [x] OpenChoreo SRE Agent
* [x] OpenChoreo FinOps Agent
* [x] OpenChoreo Portal Assistant
* [x] OpenAI credential automation
* [x] OpenAI key rotation workflow
* [x] Financial Operations Agent
* [x] Financial Agent deterministic fallback
* [x] Financial Agent OpenAI tool-calling mode
* [x] OpenChoreo MCP consumption
* [x] Customer MCP
* [x] Risk MCP
* [x] Compliance MCP
* [x] Telecom MCP
* [x] Governed telecom QoD operation
* [x] Telecom policy decision
* [x] Legacy BSS adaptation
* [x] Real Kubernetes operations console
* [x] Kubernetes self-healing scenario
* [x] Custom Platform Portal
* [x] Optional Rancher integration
* [x] Strict Rancher qualification
* [x] Reproducible clean-room rebuild
* [x] Source-level validation
* [x] Runtime verification
* [x] Capability verification
* [x] Showcase-readiness verification

---

# 112. Principal architecture takeaway

The most important point of this repository is not the individual banking or telecom applications.

The architectural value is the separation of responsibility:

```text
Application team
     │
     │ declares intent
     ▼
OpenChoreo application model
     │
     │ consumes
     ▼
Platform-owned golden paths
     │
     ├── ProjectType
     ├── ComponentType
     ├── Traits
     ├── ResourceTypes
     ├── Workflows
     ├── Authorization
     └── Observability policies
     │
     │ renders/governs
     ▼
Kubernetes runtime
```

And, for operations:

```text
Telemetry + platform state + domain APIs
                   │
                   ▼
              MCP tools
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
Operational agents       Business agents
SRE / RCA                Financial Ops
FinOps                   Telecom workflows
```

This is the central demonstration:

> **OpenChoreo provides the platform primitives; the platform engineering team turns those primitives into organization-specific golden paths, controls, managed resources, workflows, and operational experiences.**

The repository then proves those abstractions end-to-end against real Kubernetes resources, real application calls, real policy failure paths, real release promotion, real observability events, and optional AI-assisted operations.

---

# 113. Quick-start summary

For a fresh non-AI demo:

```bash
./scripts/self-test.sh
./demo.sh up
./demo.sh status
./demo.sh capabilities
```

For AI:

```bash
read -rsp "OpenAI API key: " OPENAI_API_KEY
echo
export OPENAI_API_KEY

export OPENCHOREO_AGENT_MODEL="gpt-5.4"

./demo.sh ai

unset OPENAI_API_KEY
```

Run core scenarios:

```bash
./demo.sh scenario payment
./demo.sh scenario challenge
./demo.sh scenario hold
./demo.sh scenario block
./demo.sh scenario platform-engineering
./demo.sh scenario regulated-gate-fail
./demo.sh scenario regulated-gate-pass
./demo.sh scenario promotion
./demo.sh scenario sre
./demo.sh scenario finops
./demo.sh scenario self-heal
./demo.sh scenario qod
./demo.sh scenario residency
./demo.sh scenario legacy
```

Final readiness:

```bash
./demo.sh verify
./demo.sh capabilities
./demo.sh readiness
```

For the strongest reproducibility evidence:

```bash
./demo.sh reset \
  | tee /tmp/openchoreo-platform-clean-room.log
```
<!-- PLATFORM-ARTIFACTS-UI -->
## Dynamic Platform Artifacts inside the OpenChoreo UI

The demo extends the **native OpenChoreo Backstage portal** with a read-only **Platform Artifacts** page at:

```text
http://openchoreo.localhost:8080/platform-artifacts
```

This page is part of the normal customer bootstrap. There is no separate UI installation procedure after the extension is committed to this repository:

```bash
./demo.sh reset
```

The reset installs OpenChoreo, creates the custom platform artifacts and all 19 application Components, then automatically builds and deploys the enhanced OpenChoreo portal and verifies it before the clean-room run is declared successful.

The page discovers live OpenChoreo objects dynamically. Demo-owned definitions carry source-controlled ownership metadata in their committed manifests:

```yaml
metadata:
  labels:
    demo.openchoreo.dev/custom-artifact: "true"
```

The bootstrap also reconciles this metadata on the live objects before validating the portal, so an interrupted UI build cannot leave the catalog silently empty.

The current showcase highlights `regulated-platform`, `regulated-service`, `bank-runtime-hardening`, `platform-valkey-cache`, `regulated-release-gate`, `platform-policy-gate`, the standard delivery pipeline, managed payment cache, environments, alert channels and authorization artifacts. New supported objects carrying the same label appear automatically on the next UI refresh; the frontend does not contain a hard-coded list of artifact names.

The drill-down presents Overview, Parameters, Composition and a structured definition before offering Raw YAML, preserving OpenChoreo's platform-abstraction story while keeping the underlying CRD definition one click away.

### Architecture-safe portal build

The OpenChoreo runtime is pinned to **v1.2.2**, and the custom portal source is therefore pinned to the matching `openchoreo/backstage-plugins` **v1.2.2** tag. The upstream v1.2.2 Backstage Dockerfile pins build stages to `linux/amd64`; this repository removes that build-stage pin and builds for the actual k3d node architecture (`arm64` or `amd64`). This is required for Apple Silicon/Colima and also keeps Intel/AMD customer environments working without a separate script.

Host Node.js and Yarn are **not required** for the custom portal. Yarn lockfile resolution and the complete Backstage production build run in Docker. The first clean bootstrap is therefore slower because it builds the portal once; subsequent `./demo.sh up` runs reuse the matching local architecture image when available. A new clean k3d cluster automatically reimports that image.

The local image uses `imagePullPolicy: Never`, so Kubernetes never attempts to pull the demo-only image from Docker Hub or another registry.

If an environment upgraded from an older revision ever shows `0` custom artifacts, repair the live metadata without rebuilding Backstage:

```bash
./extensions/platform-artifacts-ui/scripts/repair-platform-artifacts-metadata.sh
```

Useful verification:

```bash
./extensions/platform-artifacts-ui/scripts/verify-platform-artifacts-ui.sh
kubectl get deployment backstage -n openchoreo-control-plane \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl get node -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture
```

For a deliberate rebuild of only the custom portal:

```bash
./extensions/platform-artifacts-ui/scripts/deploy-platform-artifacts-ui.sh
```

Normal users and customers should not need that command; `./demo.sh reset` and `./demo.sh up` call the idempotent ensure flow automatically.

