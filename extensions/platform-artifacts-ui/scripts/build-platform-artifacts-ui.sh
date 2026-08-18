#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=platform-artifacts-lib.sh
source "$ROOT/scripts/platform-artifacts-lib.sh"

WORK_ROOT="${PLATFORM_ARTIFACTS_WORK_ROOT:-$ROOT/.work}"
SRC="${BACKSTAGE_SOURCE_DIR:-$WORK_ROOT/backstage-plugins}"
UPSTREAM="${OPENCHOREO_BACKSTAGE_REPO:-https://github.com/openchoreo/backstage-plugins.git}"
# Keep the portal source aligned with the OpenChoreo runtime shipped by this demo.
REF="${OPENCHOREO_BACKSTAGE_REF:-v1.2.2}"
ARCH="$(pa_target_arch)"
PLATFORM="linux/$ARCH"
IMAGE="$(pa_default_image "$ARCH")"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is required" >&2; exit 1; }; }
need git
need docker
need python3

mkdir -p "$WORK_ROOT"

if [[ ! -d "$SRC/.git" ]]; then
  rm -rf "$SRC"
  echo "==> Cloning OpenChoreo Backstage source"
  git clone --filter=blob:none --no-checkout "$UPSTREAM" "$SRC"
fi

# Reset a cached checkout so repeated builds are deterministic and do not stack patches.
echo "==> Resolving OpenChoreo Backstage revision: $REF"
git -C "$SRC" fetch --depth 1 origin "refs/tags/$REF:refs/tags/$REF" 2>/dev/null || \
  git -C "$SRC" fetch --depth 1 origin "$REF"
git -C "$SRC" checkout --detach "$REF" 2>/dev/null || git -C "$SRC" checkout --detach FETCH_HEAD
git -C "$SRC" reset --hard HEAD
git -C "$SRC" clean -fdx

REVISION="$(git -C "$SRC" rev-parse HEAD)"
printf '%s\n' "$REVISION" > "$WORK_ROOT/backstage.revision"
printf '%s\n' "$REF" > "$WORK_ROOT/backstage.ref"
printf '%s\n' "$ARCH" > "$WORK_ROOT/platform-artifacts.arch"

echo "==> Overlaying Platform Artifacts plugins"
rm -rf "$SRC/plugins/platform-artifacts" "$SRC/plugins/platform-artifacts-backend"
cp -R "$ROOT/overlay/plugins/platform-artifacts" "$SRC/plugins/platform-artifacts"
cp -R "$ROOT/overlay/plugins/platform-artifacts-backend" "$SRC/plugins/platform-artifacts-backend"

python3 "$ROOT/scripts/patch-openchoreo-backstage.py" "$SRC"
python3 "$ROOT/scripts/patch-openchoreo-dockerfile.py" "$SRC/packages/backend/Dockerfile"

# The overlay introduces two workspaces. We only need Yarn to update yarn.lock here;
# --mode=update-lockfile deliberately skips the expensive link/build step. The
# official production Dockerfile performs the immutable full install during build.
echo "==> Updating Yarn workspace lockfile (containerized, no host Node/Yarn required)"
docker run --rm \
  --platform "$PLATFORM" \
  -v "$SRC:/app" \
  -w /app \
  node:22-bookworm \
  bash -lc 'corepack enable && corepack prepare yarn@4.4.1 --activate && yarn install --mode=update-lockfile'

echo "==> Building architecture-native OpenChoreo portal image"
echo "    Target platform: $PLATFORM"
echo "    Image:           $IMAGE"
echo "    OpenChoreo UI:   $REF ($REVISION)"

docker buildx build \
  --platform "$PLATFORM" \
  --provenance=false \
  -f "$SRC/packages/backend/Dockerfile" \
  -t "$IMAGE" \
  --load \
  "$SRC"

ACTUAL_ARCH="$(pa_image_arch "$IMAGE" || true)"
NORMALIZED="$(pa_normalize_arch "$ACTUAL_ARCH" 2>/dev/null || true)"
if [[ "$NORMALIZED" != "$ARCH" ]]; then
  echo "ERROR: built image architecture '$ACTUAL_ARCH' does not match target '$ARCH'" >&2
  exit 1
fi

printf '%s\n' "$IMAGE" > "$WORK_ROOT/platform-artifacts.image"
echo "==> Built $IMAGE for $ARCH from backstage-plugins@$REVISION"
