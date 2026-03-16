#!/usr/bin/env bash

set -euo pipefail

# Notification replacement ID (fixed)
ID=2000

# Smooth brightness transition
smooth_set() {
    current=$1
    target=$2

    # Calculate step direction
    if [ "$target" -eq "$current" ]; then
        return
    elif [ "$target" -gt "$current" ]; then
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

case "${1:-}" in
    up)
        current=$(brightnessctl get)
        max=$(brightnessctl max)
        min=$((max / 100))  # minimum 1%
        [ "$min" -lt 1 ] && min=1
        step=$((max / 100))  # 1% step
        [ "$step" -lt 1 ] && step=1
        target=$((current + step))
        if [ "$target" -gt "$max" ]; then
            target=$max
        fi
        smooth_set "$current" "$target"
        ;;
    down)
        current=$(brightnessctl get)
        max=$(brightnessctl max)
        min=$((max / 100))  # minimum 1%
        [ "$min" -lt 1 ] && min=1
        step=$((max / 100))  # 1% step
        [ "$step" -lt 1 ] && step=1
        if [ "$current" -le "$min" ]; then
            # Do not increase brightness on a down action if we're already below floor.
            target=$current
        else
            target=$((current - step))
        fi
        if [ "$target" -lt "$min" ]; then
            target=$min
        fi
        smooth_set "$current" "$target"
        ;;
    *)
        echo "Usage: brightness-control.sh {up|down}" >&2
        exit 1
        ;;
esac

# Get current brightness percentage for notification
current=$(brightnessctl get)
max=$(brightnessctl max)
# Round to nearest integer so notification matches waybar's displayed percent.
if [ "$max" -gt 0 ]; then
    percent=$(((current * 100 + max / 2) / max))
else
    percent=0
fi

# Select icon
if [ "$percent" -lt 30 ]; then
    icon="󰃞"
elif [ "$percent" -lt 70 ]; then
    icon="󰃟"
else
    icon="󰃠"
fi

# Send notification with progress bar
notify-send -r "$ID" \
    -h string:x-canonical-private-synchronous:brightness \
    -h int:value:"$percent" \
    "$icon  Brightness: ${percent}%"
