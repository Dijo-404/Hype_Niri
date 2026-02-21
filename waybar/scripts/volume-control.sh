#!/bin/bash

# File to store notification ID
ID_FILE="/tmp/notify-volume-id"

send_notification() {
    if [ -f "$ID_FILE" ]; then
        ID=$(cat "$ID_FILE")
        notify-send -p -r "$ID" "$@" > "$ID_FILE"
    else
        notify-send -p "$@" > "$ID_FILE"
    fi
}

case "$1" in
    up)
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac

# Get current volume and mute status
vol_info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
vol=$(echo "$vol_info" | awk '{print int($2 * 100)}')
mute=$(echo "$vol_info" | grep "MUTED")

if [ -n "$mute" ]; then
    # Muted state
    send_notification \
        "󰝟  Muted"
else
    # Select icon based on volume level
    if [ "$vol" -lt 30 ]; then
        icon="󰕿"
    elif [ "$vol" -lt 70 ]; then
        icon="󰖀"
    else
        icon="󰕾"
    fi
    
    send_notification \
        -h int:value:"$vol" \
        "$icon  Volume: ${vol}%"
fi
