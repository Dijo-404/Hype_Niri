#!/bin/bash

command -v wpctl >/dev/null 2>&1 || exit 0

ID=2003

case "$1" in
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
esac

mic_info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
mute=$(echo "$mic_info" | grep "MUTED")

if [ -n "$mute" ]; then
    notify-send -r "$ID" \
        "󰍭  Microphone Muted"
else
    notify-send -r "$ID" \
        "󰍬  Microphone Active"
fi
