# OpenChoreo Financial Services Showcase — Operator Runbook

## Qualification, before the event

From the repository root:

```bash
./scripts/showcase-freeze-rancher.sh
source .showcase.env
./demo.sh reset
./demo.sh readiness
```

If AI capabilities are part of the presentation, enable them during qualification rather than during the customer conversation:

```bash
source .showcase.env
export OPENAI_API_KEY='...'
export OPENCHOREO_AGENT_MODEL='gpt-5.4'
export SHOWCASE_ENABLE_AI=1
./demo.sh prepare
unset OPENAI_API_KEY
```

Run `./demo.sh readiness` again after every machine restart, network change, Docker/Colima restart, or source modification.

## Customer story

Start with a banking outcome in the Financial Experience. Follow the transaction into OpenChoreo and show the System/Component views, rather than immediately opening Kubernetes.

Then show how the platform team encoded the regulated golden path: `regulated-platform`, the three-environment pipeline, immutable releases and bindings, the managed cache Resource, Traits, authorization boundaries, and the workflow policy gate.

Use observability as a connected story: logs/metrics/traces → alert → RCA/cost analysis. If the built-in agents are enabled, demonstrate them from OpenChoreo; keep the Portal Assistant framed as read-only assistance.

Only then move down one level to Kubernetes Operations to prove that OpenChoreo is deploying real Kubernetes workloads and enforcing generated runtime controls.

Finish in SUSE Rancher. Show the same cluster, namespaces, workloads and Rancher agents. The message is complementarity: OpenChoreo provides the developer-platform abstraction, software delivery and governance; Rancher gives the infrastructure/operator view of the Kubernetes estate.

## Recovery

The presentation path must always remain available without AI-provider access. AI is an enhancement, not a prerequisite for the core OpenChoreo demonstration.

For a clean reset:

```bash
source .showcase.env
./demo.sh reset
./demo.sh readiness
```

For controlled scenario resets, keep using the repository's existing `./demo.sh scenario ...` flows.
