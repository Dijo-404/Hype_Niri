#!/bin/bash

command -v wpctl >/dev/null 2>&1 || exit 0

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

vol_info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
vol=$(echo "$vol_info" | awk '{print int($2 * 100)}')
mute=$(echo "$vol_info" | grep "MUTED")

if [ -n "$mute" ]; then
    notify-send -r "$ID" \
        -h string:x-canonical-private-synchronous:volume \
        "󰝟  Muted"
else
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
