#!/bin/bash

# Replace ID for deduplicating notifications
REPLACE_ID=2000

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
    notify-send -r "$REPLACE_ID" \
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
    
    notify-send -r "$REPLACE_ID" \
        -h int:value:"$vol" \
        "$icon  Volume: ${vol}%"
fi
