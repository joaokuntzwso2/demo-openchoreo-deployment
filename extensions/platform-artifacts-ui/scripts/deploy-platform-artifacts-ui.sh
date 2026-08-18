#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REUSE=0
for arg in "$@"; do
  case "$arg" in
    --reuse-image) REUSE=1 ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$REUSE" == "1" ]]; then
  exec "$ROOT/scripts/ensure-platform-artifacts-ui.sh"
else
  exec "$ROOT/scripts/ensure-platform-artifacts-ui.sh" --force-build
fi
