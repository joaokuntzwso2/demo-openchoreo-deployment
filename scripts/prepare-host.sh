#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"

[[ "$(uname -s)" == "Darwin" ]] || exit 0
command -v colima >/dev/null 2>&1 || exit 0
colima status >/dev/null 2>&1 || exit 0

log "Preparing Colima inotify limits"
colima ssh -- sudo sysctl -w fs.inotify.max_user_instances=2048 >/dev/null
colima ssh -- sudo sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null
colima ssh -- sudo sysctl -w fs.inotify.max_queued_events=32768 >/dev/null

instances="$(colima ssh -- sysctl -n fs.inotify.max_user_instances | tr -d '\r')"
watches="$(colima ssh -- sysctl -n fs.inotify.max_user_watches | tr -d '\r')"
queued="$(colima ssh -- sysctl -n fs.inotify.max_queued_events | tr -d '\r')"

[[ "$instances" -ge 2048 ]] || die "max_user_instances=$instances"
[[ "$watches" -ge 1048576 ]] || die "max_user_watches=$watches"
[[ "$queued" -ge 32768 ]] || die "max_queued_events=$queued"
