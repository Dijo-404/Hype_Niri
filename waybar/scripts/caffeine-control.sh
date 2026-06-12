#!/usr/bin/env bash

set -euo pipefail

# Per-user runtime dir only -- refuse /tmp fallback (world-writable).
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ ! -d "$RUNTIME_DIR" ] || [ ! -w "$RUNTIME_DIR" ]; then
    echo '{"text": "", "tooltip": "runtime dir unavailable", "class": "deactivated"}'
    exit 0
fi
STATE_FILE="$RUNTIME_DIR/caffeine_state"
PID_FILE="$RUNTIME_DIR/caffeine_pid"
ID=2002

read_pid_file() {
    local pid=""
    if [ -f "$PID_FILE" ]; then
        read -r pid < "$PID_FILE" 2>/dev/null || pid=""
        [[ "$pid" =~ ^[0-9]+$ ]] || pid=""
    fi
    printf '%s' "$pid"
}

is_inhibitor_pid() {
    local pid="$1"
    local cmdline
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1

    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
    [[ "$cmdline" == *"systemd-inhibit"* && "$cmdline" == *"sleep infinity"* ]]
}

is_current_inhibitor_pid() {
    local pid="$1"
    local cmdline
    is_inhibitor_pid "$pid" || return 1

    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
    [[ "$cmdline" == *"--what=idle "* ]]
}

start_inhibitor() {
    local existing_pid
    existing_pid=$(read_pid_file)
    if [ -n "$existing_pid" ] && is_inhibitor_pid "$existing_pid" && kill -0 "$existing_pid" 2>/dev/null; then
        kill "$existing_pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"

    systemd-inhibit --what=idle --who="Caffeine Mode" --why="User requested stay awake" --mode=block -- sleep infinity >/dev/null 2>&1 &
    echo "$!" > "$PID_FILE"
}

stop_inhibitor() {
    local existing_pid
    existing_pid=$(read_pid_file)
    if [ -n "$existing_pid" ] && is_inhibitor_pid "$existing_pid" && kill -0 "$existing_pid" 2>/dev/null; then
        kill "$existing_pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
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
        notify-send -r "$ID" "󰾪  Caffeine Mode Deactivated" "Idle lock and display sleep restored"
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    else
        touch "$STATE_FILE"
        start_inhibitor
        notify-send -r "$ID" "󰅶  Caffeine Mode Active" "Idle lock and display sleep paused"
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    fi
    pkill -RTMIN+15 waybar || true
else
    if [ -f "$STATE_FILE" ]; then
        existing_pid=$(read_pid_file)
        if [ -z "$existing_pid" ] || ! is_current_inhibitor_pid "$existing_pid" || ! kill -0 "$existing_pid" 2>/dev/null; then
            start_inhibitor
        fi
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    else
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    fi
fi
