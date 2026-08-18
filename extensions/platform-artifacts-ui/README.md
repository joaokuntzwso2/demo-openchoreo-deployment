<!-- Platform Artifacts UI v3.1 -->
# OpenChoreo Platform Artifacts UI — Customer-Ready Integration (v3.1)

This extension adds a first-class **Platform Artifacts** experience to the native OpenChoreo developer portal. It turns live OpenChoreo platform-engineering CRs into a professional, read-only catalog with cards, search, filters, structured drill-downs, composition views, parameter views and optional raw YAML.

It is designed for the `demo-openchoreo-deployment` repository running **OpenChoreo v1.2.2**.

## Customer experience

After this extension is integrated and committed into the demo repository, the customer does **not** install the UI separately.

From a fresh clone or extracted ZIP, the intended flow is simply:

```bash
chmod +x demo.sh scripts/*.sh extensions/platform-artifacts-ui/scripts/*.sh
./demo.sh reset
```

`./demo.sh reset` performs the whole clean-room workflow:

```text
workstation preflight
        ↓
OpenChoreo v1.2.2 installation
        ↓
custom OpenChoreo platform abstractions
        ↓
10 Projects / 30 ProjectReleaseBindings
        ↓
managed resources / authorization / workflows / traits
        ↓
19 application Components
        ↓
financial + telecom data
        ↓
Rancher integration
        ↓
architecture-native Platform Artifacts portal build
        ↓
custom portal import + rollout
        ↓
live artifact metadata
        ↓
core + Platform Artifacts verification
        ↓
FULL CLEAN-ROOM RUN PASSED
```

There is no second customer installation step.

## Platform Artifacts page

Open:

```text
http://openchoreo.localhost:8080/platform-artifacts
```

The page also appears in the OpenChoreo sidebar as **Platform Artifacts**.

The UI presents live resources by platform concept rather than as large YAML files:

- Golden Paths
- Security & Runtime Policy
- Managed Resources
- Governance Workflows
- Delivery
- Delivery Environments
- Observability
- Access Control

Selecting an artifact opens a structured drawer with:

- Overview
- metadata and scope
- equivalent `kubectl get ... -o yaml` command
- parameters/environment schema where present
- composition-oriented fields such as resources, traits, outputs, steps and conditions
- structured recursive definition
- Raw YAML as the final optional view

## Dynamic discovery

The frontend does not hard-code names such as `regulated-service` or `bank-runtime-hardening`.

Supported live OpenChoreo resources are queried through the Backstage backend on every refresh. The page refreshes automatically every 12 seconds and also provides a manual Refresh action.

A resource is highlighted as organization-owned/custom when it has:

```yaml
metadata:
  labels:
    demo.openchoreo.dev/custom-artifact: "true"
```

Optional presentation annotations are:

```yaml
metadata:
  annotations:
    demo.openchoreo.dev/display-name: "Regulated Service"
    demo.openchoreo.dev/category: "Golden Path"
    demo.openchoreo.dev/description: "Reusable regulated service golden path."
```

A future supported ProjectType, ComponentType, Trait, ResourceType, Workflow, Resource, Environment, delivery object, notification channel or authorization object with that label appears without rebuilding React.

## Current custom artifacts highlighted by the demo

The metadata helper marks the current showcase objects, including:

```text
ClusterProjectType/regulated-platform
ClusterComponentType/regulated-service
ClusterTrait/bank-runtime-hardening
ClusterResourceType/platform-valkey-cache
ClusterWorkflow/regulated-release-gate
Workflow/platform-policy-gate
DeploymentPipeline/platform-standard
Resource/payment-idempotency-cache
Environment/development
Environment/staging
Environment/production
ObservabilityAlertsNotificationChannel/platform-webhook-development
ObservabilityAlertsNotificationChannel/platform-webhook-staging
ObservabilityAlertsNotificationChannel/platform-webhook-production
AuthzRole/platform-auditor
ClusterAuthzRoleBinding/platform-demo-developers
AuthzRoleBinding/platform-demo-auditors
```

## Supported artifact families

The backend currently discovers:

```text
ClusterProjectType
ClusterComponentType
ClusterTrait
ClusterResourceType
ClusterWorkflow
ClusterAuthzRole
ClusterAuthzRoleBinding
ProjectType
ComponentType
Trait
ResourceType
Workflow
DeploymentPipeline
Environment
Resource
ObservabilityAlertsNotificationChannel
AuthzRole
AuthzRoleBinding
```

The descriptor list is in:

```text
overlay/plugins/platform-artifacts-backend/src/router.ts
```

The frontend is generic; adding another supported collection normally requires only a backend collection descriptor, not a new card implementation.

## Security model

The extension is deliberately **read-only**.

The browser uses Backstage `fetchApiRef`. OpenChoreo v1.2.2 replaces the default fetch implementation with `OpenChoreoFetchApi`, which sends the Backstage identity token in `Authorization` and the user's OpenChoreo IDP token in `x-openchoreo-token`. The Platform Artifacts backend forwards the OpenChoreo token to the OpenChoreo API, so visibility follows the signed-in user's OpenChoreo authorization.

The browser receives no Kubernetes credentials and the extension creates no privileged Kubernetes ServiceAccount.

The backend also redacts obvious credential-shaped fields such as authorization headers, API keys, tokens, passwords, client secrets and secret values before returning definitions to the browser.

## Apple Silicon and multi-architecture support

This section is important.

The official OpenChoreo Backstage **v1.2.2** Dockerfile hard-codes its first two build stages to:

```dockerfile
FROM --platform=linux/amd64 node:22-bookworm-slim
```

That produces an amd64-oriented build even when the OpenChoreo k3d node is arm64. On Apple Silicon/Colima this can leave the custom Backstage Pod in `ImagePullBackOff`/unusable state while the stock portal continues serving.

The customer-ready build fixes that automatically.

`ensure-platform-artifacts-ui.sh` detects the actual Kubernetes node architecture:

```text
arm64
or
amd64
```

The source preparation then removes the upstream hard-coded `linux/amd64` build-stage pins and Buildx builds the full Backstage image for:

```text
linux/arm64
or
linux/amd64
```

The local image is architecture-specific by default:

```text
openchoreo-ui-platform-artifacts:local-arm64
openchoreo-ui-platform-artifacts:local-amd64
```

The deployment uses:

```yaml
imagePullPolicy: Never
```

because the image is imported directly into the local k3d node and must never be fetched from Docker Hub.

The verifier rejects an image whose architecture does not match the k3d node.

## OpenChoreo source compatibility

The demo runtime is OpenChoreo **v1.2.2**, so the portal source is pinned by default to:

```bash
OPENCHOREO_BACKSTAGE_REF=v1.2.2
```

This is intentionally different from following `main`.

The source patcher supports the v1.2.2 `createApp({ features: [...] })` portal composition and also contains a guarded compatibility path for the newer `createPortalApp` structure. If OpenChoreo changes the app/sidebar/backend composition in an unsupported way, the build fails explicitly rather than silently generating an incomplete portal.

## No host Node.js or Yarn required

The custom portal build is containerized.

The lockfile update runs inside `node:22-bookworm` using Yarn 4.4.1. It uses:

```bash
yarn install --mode=update-lockfile
```

so Yarn updates the workspace lockfile without performing the expensive link step. The official Backstage production Docker build then performs the immutable installation and package build.

Host Node.js remains optional for the main demo, just as before.

## Why there is no Docker Compose file

A Docker Compose wrapper is intentionally not used for this extension.

OpenChoreo already creates and owns the k3d control-plane/data-plane topology. Running another Backstage instance through Compose would create a second orchestration and routing model, duplicate authentication/configuration, and make the demonstration less representative of OpenChoreo.

Docker is still used for all custom portal compilation and image creation. Kubernetes/OpenChoreo remains the only runtime orchestrator.

## Repository integration

For the repository owner, use the integration bundle once:

```bash
./scripts/install-into-demo-repo.sh /path/to/demo-openchoreo-deployment
```

or:

```bash
./scripts/integrate-customer-ready.sh /path/to/demo-openchoreo-deployment
```

This copies the extension into:

```text
extensions/platform-artifacts-ui
```

and idempotently updates the demo repository so the enhancement is part of normal lifecycle commands.

The integration patches:

```text
scripts/bootstrap-all.sh
scripts/verify-clean-room.sh
scripts/status.sh
scripts/preflight.sh
scripts/self-test.sh
.showcase.env.example
.gitignore
README.md
```

It also repairs the known malformed `self-test.sh` `printf` regression if that exact regression exists.

After running the integration script, review and commit the repository changes. Customers then use only the normal demo commands.

## Normal lifecycle after integration

Fresh clone / customer qualification:

```bash
./demo.sh reset
```

Idempotent reconciliation of an existing environment:

```bash
./demo.sh up
```

Verification:

```bash
./demo.sh verify
```

Status now includes:

```text
Platform Artifacts: http://openchoreo.localhost:8080/platform-artifacts
```

## Manual portal rebuild

Normal customers do not need this.

To force a new portal build and deploy it into an already-running OpenChoreo environment:

```bash
./extensions/platform-artifacts-ui/scripts/deploy-platform-artifacts-ui.sh
```

To reuse a matching local image when possible:

```bash
./extensions/platform-artifacts-ui/scripts/deploy-platform-artifacts-ui.sh --reuse-image
```

The idempotent bootstrap uses the more appropriate command internally:

```bash
./extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh
```

## Upgrade an existing repository and running demo in one command

For the repository owner migrating from the first extension version, run this from the extracted v2 bundle:

```bash
./scripts/upgrade-current-demo.sh /path/to/demo-openchoreo-deployment
```

It installs the corrected customer-ready extension into the repository and, when the OpenChoreo k3d cluster is already running, immediately rebuilds/redeploys the portal for the correct architecture.

## Recover the currently-running Apple Silicon environment

If an earlier version deployed `openchoreo-ui-platform-artifacts:local` as amd64 into an arm64 k3d cluster, install this corrected extension and run:

```bash
./extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh --force-build
```

The script will detect `arm64`, build `openchoreo-ui-platform-artifacts:local-arm64`, import it into k3d, change the Backstage Deployment to the architecture-correct image and wait for the rollout.

The stock OpenChoreo pod remains available during the rolling update until the new portal is Ready.

## Verification

```bash
./extensions/platform-artifacts-ui/scripts/verify-platform-artifacts-ui.sh
```

The verifier checks:

- Backstage Deployment rollout is complete
- expected custom architecture-specific image is active
- Docker image architecture matches the k3d node architecture
- `imagePullPolicy` is `Never`
- representative custom artifacts carry the custom-artifact label
- the `/platform-artifacts` route is reachable when the local gateway is available

Useful manual evidence:

```bash
kubectl get node \
  -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

docker image inspect openchoreo-ui-platform-artifacts:local-arm64 \
  --format 'Architecture={{.Architecture}} OS={{.Os}}'

kubectl get deployment backstage \
  -n openchoreo-control-plane \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Rollout diagnostics

If the custom portal cannot become Ready, the ensure script automatically prints:

- target cluster architecture
- local image architecture
- Backstage Deployment state
- ReplicaSets
- Backstage Pods
- `kubectl describe` for the custom Pod
- current and previous container logs

The timeout defaults to:

```bash
PLATFORM_ARTIFACTS_ROLLOUT_TIMEOUT=10m
```

Override only when necessary.

## Roll back to stock OpenChoreo UI

The deployment flow records the original stock Backstage image and pull policy in Deployment annotations before the first transition to the custom image.

Restore it with:

```bash
./extensions/platform-artifacts-ui/scripts/uninstall-platform-artifacts-ui.sh
```

The artifact labels/annotations are intentionally left in place because they are harmless metadata and remain useful platform documentation.

## File inventory

```text
extensions/platform-artifacts-ui/
├── README.md
├── overlay/
│   └── plugins/
│       ├── platform-artifacts/
│       └── platform-artifacts-backend/
└── scripts/
    ├── build-platform-artifacts-ui.sh
    ├── deploy-platform-artifacts-ui.sh
    ├── ensure-platform-artifacts-ui.sh
    ├── install-into-demo-repo.sh
    ├── integrate-customer-ready.sh
    ├── label-demo-artifacts.sh
    ├── patch-demo-hook.py
    ├── patch-demo-repository.py
    ├── patch-openchoreo-backstage.py
    ├── patch-openchoreo-dockerfile.py
    ├── platform-artifacts-lib.sh
    ├── uninstall-platform-artifacts-ui.sh
    ├── upgrade-current-demo.sh
    └── verify-platform-artifacts-ui.sh
```

## Presenter positioning

A strong demonstration sequence is:

1. Open **Platform Artifacts**.
2. Show **Regulated Platform** as the custom ProjectType defining regulated project/environment cells.
3. Show **Regulated Service** as the application golden path.
4. Open **Bank Runtime Hardening** and show the security patches and PDB through the structured view.
5. Compare **Platform Valkey Cache** (ResourceType) with **Payment Idempotency Cache** (Resource instance).
6. Show **Regulated Release Gate** and **Platform Policy Gate**.
7. Show environments, alert channels and authorization objects.
8. Open Raw YAML only when someone wants CRD-level proof.

This keeps the OpenChoreo platform-abstraction model as the primary story while preserving implementation evidence one click away.


## v3.1: macOS Bash compatibility

The live metadata reconciler and verifier avoid expanding empty Bash arrays. This matters on macOS, whose system Bash can raise `unbound variable` under `set -u` for an empty local array. Cluster-scoped and namespace-scoped `kubectl` calls now use explicit branches, so the same scripts work on macOS/Colima and modern Linux Bash without customer-side workarounds.

## v3: source-controlled ownership metadata and zero-count protection

The Platform Artifacts page classifies demo-owned definitions through the label:

```yaml
metadata:
  labels:
    demo.openchoreo.dev/custom-artifact: "true"
```

Starting with v3, this label and the presentation annotations are **embedded directly into the repository manifests** during integration. The UI therefore does not depend on a one-time post-install `kubectl label` operation. The runtime `label-demo-artifacts.sh` remains in place as an idempotent reconciliation guard for already-running environments and upgrades.

The following source-controlled artifacts are marked automatically: `regulated-platform`, `regulated-service`, `bank-runtime-hardening`, `platform-valkey-cache`, `regulated-release-gate`, `platform-policy-gate`, `platform-standard`, `payment-idempotency-cache`, the three environments, the three alert notification channels, and the demo authorization role/bindings.

The customer path remains one command:

```bash
./demo.sh reset
```

The bootstrap creates the labeled OpenChoreo objects, reconciles live metadata before the custom Backstage build/deployment, and the clean-room verifier refuses to report success unless all expected Platform Artifacts metadata is present.

### Existing environment shows `0` custom artifacts

If upgrading an environment created before the source-controlled metadata was added, run once:

```bash
./extensions/platform-artifacts-ui/scripts/repair-platform-artifacts-metadata.sh
```

This does not rebuild Backstage. It patches the repository manifests, reconciles labels/annotations on the live OpenChoreo objects, and runs the verifier. The Platform Artifacts page refreshes dynamically afterward.

For diagnostics:

```bash
kubectl get clusterprojecttypes.openchoreo.dev regulated-platform \
  -o jsonpath='{.metadata.labels.demo\.openchoreo\.dev/custom-artifact}{"\n"}'
```

Expected:

```text
true
```

New platform artifacts remain dynamic: add the same label to any supported OpenChoreo object in its committed manifest and it appears in the Custom view without changing or rebuilding the React page.

