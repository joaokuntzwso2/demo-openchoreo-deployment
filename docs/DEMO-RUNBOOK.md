# Demo runbook

## Before presenting

```bash
./demo.sh verify
./demo.sh status
```

Keep the following tabs open: Platform Portal, OpenChoreo, Kubernetes Operations Console and Rancher.

## Story 1 — platform application delivery

Start in the Platform Portal, show healthy services, then switch to OpenChoreo and explain the 10 Projects and their environment cells. Open the `payments-service` Component to show its declared dependencies.

## Story 2 — financial orchestration

Run **Normal payment**. Show `ACCEPTED / ALLOW / CLEAR / UP`. Then run **Step-up challenge** or **Compliance hold** to demonstrate that the same component topology yields different governed business outcomes.

## Story 3 — telecom APIs on OpenChoreo

Open Telecom Operations. Inspect subscriber `5511999999999`, create a QoD session, check the partner wallet and trigger the data-residency deny. Then show the `telco-*` workloads in OpenChoreo.

## Story 4 — modernization

Call **Legacy BSS modernization**. The legacy component returns SOAP/XML while the façade exposes clean REST/JSON. Open Kubernetes Operations and show both Deployments and Services running in the data plane.

## Story 5 — Kubernetes proof

Open Kubernetes Operations. Show Pods, Deployments, Services, HTTPRoutes and NetworkPolicies. Restart a demo Deployment from the console and watch the Pod name change while desired state remains healthy.

## Story 6 — Rancher

Open Rancher at `https://localhost:8444`. If automatic cluster registration completed, open the `openchoreo` registered cluster and show workloads/namespaces. If registration is still pending, run `./demo.sh rancher` and use Rancher's Import Existing flow as a transparent demonstration of how the same Kubernetes cluster can be managed externally.


## Story 7 — self-healing and desired state

Run `./demo.sh scenario self-heal` (or use Restart/Delete Pod in Kubernetes Operations). Show that the old Payments pod disappears, Kubernetes creates a replacement, and OpenChoreo still reports the Component/ReleaseBinding as healthy.

## Story 8 — workflow governance

Run `./demo.sh scenario policy-gate` and show the WorkflowRun/Argo execution. Use this to distinguish application deployment from a governed release process.

## Story 9 — SRE and FinOps (optional AI)

`./demo.sh scenario sre` emits the Payments log signature used by the alert trait. `./demo.sh scenario finops` raises local OpenCost pricing so the budget story can trigger quickly. These scenarios still produce observability evidence without an LLM, but the built-in SRE/FinOps agent analysis requires a funded model credential.


## Story 10 — controlled promotion

To demonstrate environment progression without deploying the entire application twice, promote one domain slice:

```bash
./scripts/promote.sh staging financial
# or
./scripts/promote.sh staging telco
```

The script pins the managed cache when the financial slice requires it, then reuses each Component's existing immutable ComponentRelease in staging. Use OpenChoreo to compare development and staging ReleaseBindings.
