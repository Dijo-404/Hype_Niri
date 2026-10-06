#!/usr/bin/env bash
set -euo pipefail

source "${BASH_SOURCE[0]%/*}/runtime-dir.sh"
lockfile="$RUNTIME_DIR/lock-dim.lock"

(
    flock -n 9 || exit 0
    sleep 30
    pgrep -u "$UID" -x hyprlock >/dev/null 2>&1 && niri msg action power-off-monitors
) 9>"$lockfile" >/dev/null 2>&1 &

exec "$HOME/.config/scripts/lock.sh"
