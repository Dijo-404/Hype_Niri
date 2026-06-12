#!/usr/bin/env bash
set -euo pipefail

"$HOME/.config/waybar/scripts/wallpaper.sh" current >/dev/null 2>&1 || true

pidof hyprlock >/dev/null 2>&1 && exit 0

exec hyprlock --grace 0
