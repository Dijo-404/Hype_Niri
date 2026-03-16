#!/usr/bin/env bash

set -euo pipefail

# Toggle fullscreen first; then notify waybar so its hidden state tracks this action.
niri msg action fullscreen-window

if ! pgrep -x waybar >/dev/null 2>&1; then
    exit 0
fi

pkill -USR1 -x waybar || true
