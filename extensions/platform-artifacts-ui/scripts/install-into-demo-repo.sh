#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_ROOT="${1:-$PWD}"
DEMO_ROOT="$(cd "$DEMO_ROOT" && pwd)"
TARGET="$DEMO_ROOT/extensions/platform-artifacts-ui"

if [[ ! -f "$DEMO_ROOT/demo.sh" || ! -f "$DEMO_ROOT/scripts/bootstrap-all.sh" ]]; then
  echo "ERROR: '$DEMO_ROOT' does not look like demo-openchoreo-deployment" >&2
  echo "Usage: $0 /path/to/demo-openchoreo-deployment" >&2
  exit 1
fi

mkdir -p "$DEMO_ROOT/extensions"
rm -rf "$TARGET"
mkdir -p "$TARGET"

# Copy the extension itself but never copy local build cache.
tar -C "$SOURCE" --exclude='.work' -cf - . | tar -C "$TARGET" -xf -
chmod +x "$TARGET"/scripts/*.sh "$TARGET"/scripts/*.py

python3 "$TARGET/scripts/patch-custom-artifact-metadata.py" "$DEMO_ROOT"
python3 "$TARGET/scripts/patch-custom-artifact-metadata.py" "$DEMO_ROOT" --check
python3 "$TARGET/scripts/patch-demo-repository.py" "$DEMO_ROOT"

# Make all repository entry points executable for ZIP/extracted-folder users.
chmod +x "$DEMO_ROOT/demo.sh" "$DEMO_ROOT"/scripts/*.sh "$TARGET"/scripts/*.sh "$TARGET"/scripts/*.py

echo
echo "==> Customer-ready Platform Artifacts enhancement installed into the repository"
echo "    Repository: $DEMO_ROOT"
echo "    Extension:  $TARGET"
echo
echo "Commit these changes. After that, a customer only needs:"
echo "    ./demo.sh reset"
