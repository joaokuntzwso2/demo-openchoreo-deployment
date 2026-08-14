# Rancher integration

Rancher runs by default from `rancher/rancher:latest` in a standalone Docker container named `platform-rancher`, mapped to `https://localhost:8444`, with persistent data in the Docker volume `platform-rancher-data`. This is a local demonstration topology, not a production Rancher architecture.

Default local credentials:

- user: `admin`
- bootstrap password: generated locally on first start and stored in `runtime/rancher-bootstrap-password` (ignored by Git)

Override the password before first startup with `RANCHER_BOOTSTRAP_PASSWORD`.

The bootstrap attempts to create an **existing cluster registration** for the k3d `openchoreo` cluster. The script sets Rancher's downstream server URL to `https://host.k3d.internal:8444` so agents inside k3d can reach Rancher on the Docker host. Because Rancher registration behavior can vary with product version/certificates, registration is best-effort and never invalidates an otherwise healthy OpenChoreo application. Retry with:

```bash
./demo.sh rancher
```

If necessary, use Rancher → Cluster Management → Import Existing and execute its generated command against the `k3d-openchoreo` context.


For a strict demonstration acceptance gate, use:

```bash
RANCHER_REQUIRED=1 ./demo.sh reset
```

The verifier then waits for Rancher's `/ping` endpoint and for `deployment/cattle-cluster-agent` in `cattle-system` to report an available replica. Without `RANCHER_REQUIRED=1`, registration remains best-effort so a transient Rancher bootstrap delay cannot mask a healthy OpenChoreo application.

## Recovery if application bootstrap stopped before Rancher

Rancher starts before scenario seeding in the corrected package. For an already-running OpenChoreo application, Rancher can always be started or retried independently without rebuilding application workloads:

```bash
./demo.sh rancher
curl -ksS https://localhost:8444/ping
./scripts/rancher.sh verify
```

A healthy Rancher server returns `pong` from `/ping`. Browser access uses Rancher's generated development certificate, so the browser may require accepting the local certificate warning once.
