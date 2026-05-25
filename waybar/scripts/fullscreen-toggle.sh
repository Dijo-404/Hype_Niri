#!/usr/bin/env bash

set -euo pipefail

# Toggle, then signal waybar so its hidden state tracks this action.
niri msg action fullscreen-window
pgrep -x waybar >/dev/null 2>&1 || exit 0
pkill -USR1 -x waybar || true
