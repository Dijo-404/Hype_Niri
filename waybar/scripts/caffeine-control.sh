#!/usr/bin/env bash

set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUNTIME_DIR/caffeine_state"
PID_FILE="$RUNTIME_DIR/caffeine_pid"
ID=2002

is_inhibitor_pid() {
    pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1

    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
    [[ "$cmdline" == *"systemd-inhibit"* && "$cmdline" == *"sleep infinity"* ]]
}

start_inhibitor() {
    # Kill existing inhibitor if any
    if [ -f "$PID_FILE" ]; then
        existing_pid=$(cat "$PID_FILE")
        if is_inhibitor_pid "$existing_pid" && kill -0 "$existing_pid" 2>/dev/null; then
            kill "$existing_pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    
    # Start new inhibitor (prevents idle, sleep, and screen lock)
    systemd-inhibit --what=idle:sleep --who="Caffeine Mode" --why="User requested stay awake" --mode=block -- sleep infinity >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

stop_inhibitor() {
    if [ -f "$PID_FILE" ]; then
        existing_pid=$(cat "$PID_FILE")
        if is_inhibitor_pid "$existing_pid" && kill -0 "$existing_pid" 2>/dev/null; then
            kill "$existing_pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
}

action="${1:-status}"

if [ "$action" == "stop" ]; then
    rm -f "$STATE_FILE"
    stop_inhibitor
    pkill -RTMIN+15 waybar || true
elif [ "$action" == "toggle" ]; then
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        stop_inhibitor
        notify-send -r "$ID" "󰾪  Caffeine Mode Deactivated" "System will auto-suspend"
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    else
        touch "$STATE_FILE"
        start_inhibitor
        notify-send -r "$ID" "󰅶  Caffeine Mode Active" "System will stay awake"
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    fi
    pkill -RTMIN+15 waybar || true
else
    if [ -f "$STATE_FILE" ]; then
        # Ensure inhibitor is running
        if [ ! -f "$PID_FILE" ]; then
            start_inhibitor
        else
            existing_pid=$(cat "$PID_FILE")
            if ! is_inhibitor_pid "$existing_pid" || ! kill -0 "$existing_pid" 2>/dev/null; then
                start_inhibitor
            fi
        fi
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    else
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    fi
fi
