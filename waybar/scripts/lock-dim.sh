#!/usr/bin/env bash
# Super+L: lock now, then power off monitors after 30s if still locked.
# Any input powers monitors back on (niri DPMS), revealing the lock screen.
set -euo pipefail

lockfile="${XDG_RUNTIME_DIR:-/tmp}/lock-dim.lock"

# flock -n drops duplicate presses, so only one grace timer runs at a time.
(
    flock -n 9 || exit 0
    sleep 30
    pidof hyprlock >/dev/null 2>&1 && niri msg action power-off-monitors
) 9>"$lockfile" >/dev/null 2>&1 &

exec "$HOME/.config/waybar/scripts/lock.sh"
