# Validation contract

This package has two validation layers.

## Repository/source validation

`./scripts/self-test.sh` checks shell syntax, JavaScript syntax, route-prefix-aware browser code, service/Dockerfile/image cardinality, OpenChoreo Project/Component desired state, the ProjectType RBAC workaround, workflow interpolation, deterministic image import fallback, Kubernetes Operations/Rancher integration, telecom adaptation, branding and machine-independent paths.

`./scripts/validate-local-services.sh` runs the financial, MCP, telecom and unified portal service graph on local high ports when host Node.js is available. It verifies financial orchestration, governed MCP calls, commercial+policy+QoD orchestration, SOAP-to-REST modernization and the unified portal dependency graph.

## Runtime clean-room acceptance

The authoritative runtime check is:

```bash
./demo.sh reset | tee /tmp/openchoreo-platform-clean-room.log
```

The reset is not considered successful until `scripts/verify-clean-room.sh` confirms:

- 30/30 ProjectReleaseBindings Ready;
- all 19 application images physically present in the k3d node containerd image store;
- exactly 19 OpenChoreo Components and all 19 development ReleaseBindings Ready;
- the managed Valkey Resource ready;
- all development Deployments and the Valkey StatefulSet ready;
- the Platform Portal, Financial Experience, Financial Agent, Telecom Experience and Kubernetes Operations Console externally reachable;
- a real accepted financial transaction through Fraud, Compliance and Valkey;
- subscriber, network/QoD, policy and SOAP-to-REST telecom behavior;
- live Kubernetes API visibility through the Operations Console;
- the Payments observability RenderedRelease present.

Required success markers:

```text
==> CLEAN-ROOM CORE VERIFICATION PASSED
==> FULL CLEAN-ROOM RUN PASSED
```

Rancher server startup/registration is deliberately reported separately by default because the Rancher Docker server and registration agents are an auxiliary cluster-management view. A Rancher registration delay must not hide or invalidate a healthy OpenChoreo application; retry it with `./demo.sh rancher`.


Set `RANCHER_REQUIRED=1` for a stricter acceptance mode that also requires the Rancher downstream cluster agent to become Ready.
