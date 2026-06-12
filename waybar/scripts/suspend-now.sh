#!/usr/bin/env bash
set -euo pipefail

"$HOME/.config/waybar/scripts/caffeine-control.sh" stop >/dev/null 2>&1 || true

"$HOME/.config/waybar/scripts/lock-screen.sh" &

for _ in $(seq 1 40); do
    pidof hyprlock >/dev/null 2>&1 && break
    sleep 0.05
done

exec systemctl suspend
