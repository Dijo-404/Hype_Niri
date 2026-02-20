#!/bin/bash

# Wallpaper manager for swww
# Handles both single and multi-monitor setups

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/aurora_borealis.png"

# Transition settings
TRANSITION_TYPE="fade"
TRANSITION_STEP=90
TRANSITION_FPS=120
TRANSITION_DURATION=1

# Ensure swww daemon is running
if ! pgrep -x swww-daemon > /dev/null; then
    swww-daemon &
    sleep 0.3
fi

set_wallpaper() {
    local img="$1"
    if [[ -f "$img" ]]; then
        swww img "$img" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-step "$TRANSITION_STEP" \
            --transition-fps "$TRANSITION_FPS" \
            --transition-duration "$TRANSITION_DURATION"
    fi
}

case "$1" in
    init)
        # Set default wallpaper on startup (no transition)
        if [[ -f "$DEFAULT_WALLPAPER" ]]; then
            swww img "$DEFAULT_WALLPAPER" \
                --transition-type none
        fi
        ;;
    random)
        # Pick a random wallpaper
        img=$(find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | shuf -n1)
        set_wallpaper "$img"
        ;;
    select)
        # Let user pick via fuzzel
        img=$(find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | fuzzel --dmenu -p "Wallpaper: ")
        set_wallpaper "$img"
        ;;
    *)
        # Direct path provided
        if [[ -f "$1" ]]; then
            set_wallpaper "$1"
        else
            echo "Usage: wallpaper.sh {init|random|select|<path>}"
            exit 1
        fi
        ;;
esac
