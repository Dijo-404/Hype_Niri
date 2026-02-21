#!/bin/bash

# Replace file for deduplicating notifications (notify-send 0.8+)
REPLACE_FILE="/tmp/notify-brightness-id"

# Smooth brightness transition
smooth_set() {
    target=$1
    current=$(brightnessctl get)
    max=$(brightnessctl max)
    
    # Calculate step direction
    if [ "$target" -gt "$current" ]; then
        step=1
    else
        step=-1
    fi
    
    # Gradually change brightness
    while [ "$current" -ne "$target" ]; do
        current=$((current + step))
        brightnessctl -q set "$current"
        sleep 0.005
    done
}

case "$1" in
    up)
        current=$(brightnessctl get)
        max=$(brightnessctl max)
        step=$((max / 100))  # 1% step
        target=$((current + step))
        if [ "$target" -gt "$max" ]; then
            target=$max
        fi
        smooth_set "$target"
        ;;
    down)
        current=$(brightnessctl get)
        max=$(brightnessctl max)
        step=$((max / 100))  # 1% step
        target=$((current - step))
        min=$((max / 100))  # minimum 1%
        if [ "$target" -lt "$min" ]; then
            target=$min
        fi
        smooth_set "$target"
        ;;
esac

# Get current brightness percentage for notification
current=$(brightnessctl get)
max=$(brightnessctl max)
percent=$((current * 100 / max))

# Select icon
if [ "$percent" -lt 30 ]; then
    icon="󰃞"
elif [ "$percent" -lt 70 ]; then
    icon="󰃟"
else
    icon="󰃠"
fi

# Send notification with progress bar
notify-send --replace-file="$REPLACE_FILE" \
    -h int:value:"$percent" \
    "$icon  Brightness: ${percent}%"
