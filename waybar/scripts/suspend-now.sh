#!/usr/bin/env bash
set -euo pipefail

"$HOME/.config/waybar/scripts/caffeine-control.sh" stop >/dev/null 2>&1 || true

exec systemctl suspend
