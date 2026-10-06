#!/usr/bin/env bash

set -euo pipefail

source "${BASH_SOURCE[0]%/*}/runtime-dir.sh"
STATE_FILE="$RUNTIME_DIR/caffeine_state"
PID_FILE="$RUNTIME_DIR/caffeine_pid"
LOCK_FILE="$RUNTIME_DIR/caffeine.lock"
ID=2002

if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -w 2 9 || exit 0
fi

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -r "$ID" "$@" 2>/dev/null || true
}

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
    local -a cmdline=()
    local arg found_who=0 found_sleep=0
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -O "/proc/$pid" ] || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1
    mapfile -d '' -t cmdline < "/proc/$pid/cmdline" 2>/dev/null || return 1
    (( ${#cmdline[@]} >= 2 )) || return 1
    [[ "${cmdline[0]##*/}" == systemd-inhibit ]] || return 1
    INHIBITOR_WHAT=""
    for arg in "${cmdline[@]}"; do
        [[ "$arg" != '--who=Caffeine Mode' ]] || found_who=1
        [[ "$arg" != --what=* ]] || INHIBITOR_WHAT="${arg#--what=}"
    done
    if (( ${#cmdline[@]} >= 2 )); then
        [[ "${cmdline[-2]}" != sleep || "${cmdline[-1]}" != infinity ]] || found_sleep=1
    fi
    (( found_who && found_sleep ))
}

is_current_inhibitor_pid() {
    local pid="$1"
    is_inhibitor_pid "$pid" || return 1
    [[ "$INHIBITOR_WHAT" == idle ]]
}

start_inhibitor() {
    stop_inhibitor
    command -v systemd-inhibit >/dev/null 2>&1 || return 1

    systemd-inhibit --what=idle --who="Caffeine Mode" --why="User requested stay awake" --mode=block -- sleep infinity >/dev/null 2>&1 9>&- &
    local pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 0.05
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE" "$STATE_FILE"
        return 1
    fi
}

stop_inhibitor() {
    local existing_pid child
    local -a child_cmd=() children=()
    existing_pid=$(read_pid_file)
    if [ -n "$existing_pid" ] && is_inhibitor_pid "$existing_pid" && kill -0 "$existing_pid" 2>/dev/null; then
        read -r -a children < "/proc/$existing_pid/task/$existing_pid/children" 2>/dev/null || true
        for child in "${children[@]}"; do
            [ -O "/proc/$child" ] && [ -r "/proc/$child/cmdline" ] || continue
            mapfile -d '' -t child_cmd < "/proc/$child/cmdline" 2>/dev/null || continue
            (( ${#child_cmd[@]} >= 2 )) || continue
            if [[ "${child_cmd[0]##*/}" == sleep && "${child_cmd[1]:-}" == infinity ]]; then
                kill "$child" 2>/dev/null || true
            fi
        done
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
        notify "󰾪  Caffeine Mode Deactivated" "Idle lock and display sleep restored"
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    else
        if start_inhibitor; then
            : > "$STATE_FILE"
            notify "󰅶  Caffeine Mode Active" "Idle lock and display sleep paused"
            echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
        else
            notify "Caffeine unavailable" "Could not acquire the idle inhibitor"
            echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
        fi
    fi
    pkill -RTMIN+15 waybar || true
else
    if [ -f "$STATE_FILE" ]; then
        existing_pid=$(read_pid_file)
        if [ -z "$existing_pid" ] || ! is_current_inhibitor_pid "$existing_pid" || ! kill -0 "$existing_pid" 2>/dev/null; then
            if ! start_inhibitor; then
                rm -f "$STATE_FILE"
                echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
                exit 0
            fi
        fi
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    else
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    fi
fi
