#!/bin/bash

# Notification replacement ID (fixed, like mic-control.sh uses 2003)
ID=2001

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
    notify-send -r "$ID" \
        -h string:x-canonical-private-synchronous:volume \
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

    notify-send -r "$ID" \
        -h string:x-canonical-private-synchronous:volume \
        -h int:value:"$vol" \
        "$icon  Volume: ${vol}%"
fi
