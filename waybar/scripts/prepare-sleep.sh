#!/usr/bin/env bash
set -euo pipefail

wait_for_lock() {
    for _ in $(seq 1 80); do
        if pidof hyprlock >/dev/null 2>&1; then
            # Give ext-session-lock a moment to map before logind continues suspend.
            sleep 0.25
            return 0
        fi
        sleep 0.05
    done

    return 1
}

pidof hyprlock >/dev/null 2>&1 && wait_for_lock && exit 0

"$HOME/.config/waybar/scripts/wallpaper.sh" current >/dev/null 2>&1 || true

if command -v loginctl >/dev/null 2>&1; then
    if [ -n "${XDG_SESSION_ID:-}" ]; then
        loginctl lock-session "$XDG_SESSION_ID" >/dev/null 2>&1 || true
    else
        loginctl lock-session >/dev/null 2>&1 || true
    fi
fi

if ! pidof hyprlock >/dev/null 2>&1; then
    hyprlock --grace 0 --immediate-render >/dev/null 2>&1 &
fi
wait_for_lock
