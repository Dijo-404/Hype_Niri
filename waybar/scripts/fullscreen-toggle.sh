#!/bin/bash

# Keep fullscreen transitions deterministic with smoother timing.
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar_hidden_by_fullscreen"

niri msg action fullscreen-window

if ! pgrep -x waybar >/dev/null 2>&1; then
    exit 0
fi

pkill -USR1 waybar

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
else
    touch "$STATE_FILE"
fi
