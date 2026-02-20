#!/bin/bash

STATE_FILE="/tmp/caffeine_state"
PID_FILE="/tmp/caffeine_pid"
ID=2002

start_inhibitor() {
    # Kill existing inhibitor if any
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null
        rm "$PID_FILE"
    fi
    
    # Start new inhibitor (prevents idle, sleep, and screen lock)
    systemd-inhibit --what=idle:sleep --who="Caffeine Mode" --why="User requested stay awake" --mode=block sleep infinity >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

stop_inhibitor() {
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null
        rm "$PID_FILE"
    fi
}

if [ "$1" == "toggle" ]; then
    if [ -f "$STATE_FILE" ]; then
        rm "$STATE_FILE"
        stop_inhibitor
        notify-send -r "$ID" "󰾪  Caffeine Mode Deactive" "System will auto-suspend"
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    else
        touch "$STATE_FILE"
        start_inhibitor
        notify-send -r "$ID" "󰅶  Caffeine Mode Active" "System will stay awake"
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    fi
    pkill -RTMIN+15 waybar
else
    if [ -f "$STATE_FILE" ]; then
        # Ensure inhibitor is running
        if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            start_inhibitor
        fi
        echo '{"text": "󰅶", "tooltip": "Caffeine: On", "class": "activated"}'
    else
        echo '{"text": "󰾪", "tooltip": "Caffeine: Off", "class": "deactivated"}'
    fi
fi
