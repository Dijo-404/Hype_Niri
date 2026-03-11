#!/bin/bash

# Keep fullscreen transitions deterministic with smoother timing.
STATE_FILE="/tmp/waybar_hidden_by_fullscreen"

if ! pgrep -x waybar >/dev/null 2>&1; then
    niri msg action fullscreen-window
    exit 0
fi

if [ -f "$STATE_FILE" ]; then
    niri msg action fullscreen-window
    sleep 0.11
    pkill -USR1 waybar
    rm -f "$STATE_FILE"
else
    pkill -USR1 waybar
    sleep 0.11
    niri msg action fullscreen-window
    touch "$STATE_FILE"
fi
