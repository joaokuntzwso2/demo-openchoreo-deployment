#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-demo-repository.py <demo-repository-root>")

root = Path(sys.argv[1]).resolve()
if not (root / "demo.sh").exists():
    raise SystemExit(f"ERROR: {root} does not look like demo-openchoreo-deployment")


def replace_or_insert_before(path: Path, marker: str, block: str, anchor: str) -> None:
    text = path.read_text()
    if marker in text:
        pattern = re.compile(re.escape(marker) + r".*?(?=\n[^\n]*" + re.escape(anchor.strip()) + r")", re.S)
        match = pattern.search(text)
        if match:
            text = text[:match.start()] + block.rstrip() + "\n" + text[match.end():]
        else:
            # Generic marker-to-fi replacement for shell blocks.
            start = text.index(marker)
            end = text.find("\nfi", start)
            if end < 0:
                raise SystemExit(f"ERROR: could not replace existing marker block in {path}")
            end = text.find("\n", end + 1)
            if end < 0:
                end = len(text)
            text = text[:start] + block.rstrip() + "\n" + text[end+1:]
    else:
        pos = text.find(anchor)
        if pos < 0:
            raise SystemExit(f"ERROR: anchor {anchor!r} not found in {path}")
        text = text[:pos] + block.rstrip() + "\n" + text[pos:]
    path.write_text(text)


def patch_bootstrap() -> None:
    path = root / "scripts/bootstrap-all.sh"
    text = path.read_text()
    marker = "# Platform Artifacts UI extension"
    block = '''# Platform Artifacts UI extension
if [[ "${ENABLE_PLATFORM_ARTIFACTS_UI:-1}" == "1" ]]; then
  [[ -x "$ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh" ]] || die "Platform Artifacts UI extension is enabled but missing from extensions/platform-artifacts-ui"
  log "Ensuring architecture-native OpenChoreo Platform Artifacts UI"
  "$ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh"
fi
'''
    if marker in text:
        start = text.index(marker)
        # Replace through the first matching fi after marker.
        end = text.find("\nfi", start)
        if end < 0:
            raise SystemExit("ERROR: malformed existing Platform Artifacts bootstrap hook")
        end = text.find("\n", end + 1)
        if end < 0:
            end = len(text)
        text = text[:start] + block + text[end+1:]
    else:
        anchor = '"$ROOT/scripts/status.sh"'
        pos = text.find(anchor)
        if pos < 0:
            raise SystemExit("ERROR: status.sh anchor not found in bootstrap-all.sh")
        text = text[:pos] + block + text[pos:]
    path.write_text(text)


def patch_verify() -> None:
    path = root / "scripts/verify-clean-room.sh"
    text = path.read_text()
    marker = "# Verify Platform Artifacts UI extension"
    block = '''# Verify Platform Artifacts UI extension
if [[ "${ENABLE_PLATFORM_ARTIFACTS_UI:-1}" == "1" ]]; then
  log "Verifying dynamic OpenChoreo Platform Artifacts UI"
  "$ROOT/extensions/platform-artifacts-ui/scripts/verify-platform-artifacts-ui.sh"
fi
'''
    if marker not in text:
        anchor = 'log "CLEAN-ROOM CORE VERIFICATION PASSED"'
        pos = text.find(anchor)
        if pos < 0:
            raise SystemExit("ERROR: clean-room success anchor not found")
        text = text[:pos] + block + text[pos:]
        path.write_text(text)


def patch_status() -> None:
    path = root / "scripts/status.sh"
    text = path.read_text()
    line = "printf '%-28s %s\\n' 'Platform Artifacts:' 'http://openchoreo.localhost:8080/platform-artifacts'"
    if "Platform Artifacts:" not in text:
        anchor = "printf '%-28s %s\\n' 'Rancher:' 'https://localhost:8444'"
        pos = text.find(anchor)
        if pos < 0:
            raise SystemExit("ERROR: Rancher status anchor not found")
        text = text[:pos] + line + "\n" + text[pos:]
        path.write_text(text)


def patch_preflight() -> None:
    path = root / "scripts/preflight.sh"
    text = path.read_text()
    marker = "# Platform Artifacts UI build prerequisite"
    if marker not in text:
        anchor = '[[ "$missing" -eq 0 ]] || die "Install the missing prerequisites before bootstrap. See README.md."'
        pos = text.find(anchor)
        if pos < 0:
            raise SystemExit("ERROR: prerequisite anchor not found in preflight.sh")
        end = pos + len(anchor)
        block = '''
# Platform Artifacts UI build prerequisite
if [[ "${ENABLE_PLATFORM_ARTIFACTS_UI:-1}" == "1" ]] && ! command -v git >/dev/null 2>&1; then
  die "Git is required when ENABLE_PLATFORM_ARTIFACTS_UI=1 because the portal build fetches the OpenChoreo Backstage v1.2.2 source."
fi'''
        text = text[:end] + block + text[end:]
        path.write_text(text)


def repair_and_extend_self_test() -> None:
    path = root / "scripts/self-test.sh"
    lines = path.read_text().splitlines()
    repaired: list[str] = []
    i = 0
    while i < len(lines):
        # Repair the known malformed printf regression if present.
        if lines[i].strip() == "printf '" and i + 1 < len(lines) and "Fresh-clone OpenChoreo installer invariants" in lines[i + 1]:
            i += 1
            continue
        if lines[i].strip() == r"==> Static repository self-test PASSED\n'":
            repaired.append(r"printf '\n==> Static repository self-test PASSED\n'")
        else:
            repaired.append(lines[i])
        i += 1

    text = "\n".join(repaired) + "\n"
    marker = "# Platform Artifacts UI integration invariants"
    if marker not in text:
        success = r"printf '\n==> Static repository self-test PASSED\n'"
        pos = text.rfind(success)
        if pos < 0:
            raise SystemExit("ERROR: final self-test success marker not found")
        block = r'''# Platform Artifacts UI integration invariants
for f in "$ROOT"/extensions/platform-artifacts-ui/scripts/*.sh; do bash -n "$f"; done
python3 -m py_compile "$ROOT"/extensions/platform-artifacts-ui/scripts/*.py
python3 "$ROOT/extensions/platform-artifacts-ui/scripts/patch-custom-artifact-metadata.py" "$ROOT" --check
[[ -x "$ROOT/extensions/platform-artifacts-ui/scripts/ensure-platform-artifacts-ui.sh" ]] || { echo 'Platform Artifacts ensure script missing' >&2; exit 1; }
grep -q 'ensure-platform-artifacts-ui.sh' "$ROOT/scripts/bootstrap-all.sh" || { echo 'bootstrap is missing Platform Artifacts UI ensure hook' >&2; exit 1; }
grep -q 'verify-platform-artifacts-ui.sh' "$ROOT/scripts/verify-clean-room.sh" || { echo 'clean-room verifier is missing Platform Artifacts UI verification' >&2; exit 1; }
grep -q 'OPENCHOREO_BACKSTAGE_REF:-v1.2.2' "$ROOT/extensions/platform-artifacts-ui/scripts/build-platform-artifacts-ui.sh" || { echo 'Platform Artifacts build is not pinned to OpenChoreo Backstage v1.2.2' >&2; exit 1; }
grep -q 'patch-openchoreo-dockerfile.py' "$ROOT/extensions/platform-artifacts-ui/scripts/build-platform-artifacts-ui.sh" || { echo 'Platform Artifacts build is missing architecture patching' >&2; exit 1; }
if grep -q -- '--platform linux/amd64' "$ROOT/extensions/platform-artifacts-ui/scripts/build-platform-artifacts-ui.sh"; then echo 'Platform Artifacts build still hard-codes linux/amd64' >&2; exit 1; fi
printf '  architecture-native Platform Artifacts UI integration: PASS\n'

'''
        text = text[:pos] + block + text[pos:]
    path.write_text(text)


def patch_showcase_env() -> None:
    path = root / ".showcase.env.example"
    if not path.exists():
        return
    text = path.read_text()
    additions = []
    if "ENABLE_PLATFORM_ARTIFACTS_UI=" not in text:
        additions.append("ENABLE_PLATFORM_ARTIFACTS_UI=1")
    if "PLATFORM_ARTIFACTS_ROLLOUT_TIMEOUT=" not in text:
        additions.append("PLATFORM_ARTIFACTS_ROLLOUT_TIMEOUT=10m")
    if additions:
        if not text.endswith("\n"):
            text += "\n"
        text += "\n# Dynamic OpenChoreo Platform Artifacts portal extension\n" + "\n".join(additions) + "\n"
        path.write_text(text)



def patch_gitignore() -> None:
    path = root / ".gitignore"
    text = path.read_text() if path.exists() else ""
    entry = "extensions/platform-artifacts-ui/.work/"
    if entry not in text.splitlines():
        if text and not text.endswith("\n"):
            text += "\n"
        text += "\n# Generated OpenChoreo Platform Artifacts portal build cache\n" + entry + "\n"
        path.write_text(text)

def patch_readme() -> None:
    path = root / "README.md"
    text = path.read_text()

    bullet = "- **Platform Artifacts UI** — a first-class, read-only OpenChoreo portal page that dynamically presents custom ProjectTypes, ComponentTypes, Traits, ResourceTypes, Workflows, delivery artifacts, observability channels and access-control objects as structured cards and drill-down views, with raw YAML available only when needed.\n"
    if "**Platform Artifacts UI**" not in text:
        anchor = "## Architecture at a glance"
        pos = text.find(anchor)
        if pos >= 0:
            text = text[:pos] + bullet + text[pos:]

    if "- Git" not in text and "- git" not in text:
        anchor = "- Python 3\n"
        if anchor in text:
            text = text.replace(anchor, anchor + "- Git (used by the automatic Platform Artifacts UI build)\n", 1)

    marker = "<!-- PLATFORM-ARTIFACTS-UI -->"
    section = r'''<!-- PLATFORM-ARTIFACTS-UI -->
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

'''
    if marker in text:
        # Replace the existing injected section up to the next H2 or EOF.
        start = text.index(marker)
        next_h2 = text.find("\n## ", start + len(marker))
        # The first H2 is our own heading; find the following one.
        if next_h2 >= 0:
            next_h2 = text.find("\n## ", next_h2 + 4)
        if next_h2 < 0:
            text = text[:start] + section
        else:
            text = text[:start] + section + text[next_h2+1:]
    else:
        anchor = "## URLs"
        pos = text.find(anchor)
        if pos < 0:
            text += "\n" + section
        else:
            text = text[:pos] + section + text[pos:]

    # Make the customer-facing fresh-clone path one command after permissions.
    old = "chmod +x demo.sh scripts/*.sh\n./scripts/self-test.sh\n./demo.sh up"
    new = "chmod +x demo.sh scripts/*.sh extensions/platform-artifacts-ui/scripts/*.sh\n./demo.sh reset"
    text = text.replace(old, new)
    text = text.replace(
        "`./demo.sh up` is idempotent. It installs/reconciles the platform and then runs the strict verifier.",
        "`./demo.sh reset` is the recommended customer/fresh-clone path: it performs the destructive clean-room build, including the dynamic Platform Artifacts UI, and runs strict verification. `./demo.sh up` remains the idempotent reconcile path for an existing environment.",
    )

    path.write_text(text)


patch_bootstrap()
patch_verify()
patch_status()
patch_preflight()
repair_and_extend_self_test()
patch_showcase_env()
patch_gitignore()
patch_readme()
print("Customer-ready Platform Artifacts integration applied to the demo repository.")
