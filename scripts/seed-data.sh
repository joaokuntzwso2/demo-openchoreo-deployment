#!/usr/bin/env bash
# Compatibility wrapper for deterministic financial scenario seeding.
exec "$(dirname "$0")/bootstrap-data.sh" "$@"
