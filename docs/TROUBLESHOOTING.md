# Troubleshooting

## Get a complete status

```bash
./demo.sh status
./demo.sh verify
```

## Projects exist but Components are empty

The bootstrap intentionally creates Project cells before application Components. Check the first failure in the bootstrap log. The bootstrap now blocks on 30/30 Project cells and 19/19 k3d images before creating Components, so it should fail with a specific error rather than report success with an empty application.

## Image missing from k3d

`scripts/build-images.sh` builds each image as a single target architecture, imports it individually, verifies the canonical containerd tag and falls back to a direct `ctr -n k8s.io images import` if k3d silently drops an image.

## UI works but API calls fail

All browser UIs derive their OpenChoreo route prefix from `location.pathname`; the repository self-test rejects root-absolute `fetch('/api/...')` regressions. Use the external URL printed by `./demo.sh status`.

## Rancher is not registered

```bash
./demo.sh rancher
docker logs platform-rancher --tail 100
kubectl get pods -n cattle-system
```

Rancher registration is intentionally non-blocking for core application verification.
