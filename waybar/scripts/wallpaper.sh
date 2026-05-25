#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/wallpaperflare.com_wallpaper.jpg"

TRANSITION_TYPE="fade"
TRANSITION_STEP=90
TRANSITION_FPS=120
TRANSITION_DURATION=1

# Silent exit if awww missing -- called on niri startup, must not spam errors.
command -v awww >/dev/null 2>&1 || exit 0

if ! pgrep -x awww-daemon > /dev/null; then
    awww-daemon --format xrgb &
    sleep 0.3
fi

set_wallpaper() {
    local img="$1"
    if [[ -f "$img" ]]; then
        awww img "$img" \
            --transition-type "$TRANSITION_TYPE" \
            --transition-step "$TRANSITION_STEP" \
            --transition-fps "$TRANSITION_FPS" \
            --transition-duration "$TRANSITION_DURATION"
    fi
}

case "$1" in
    init)
        if [[ -f "$DEFAULT_WALLPAPER" ]]; then
            awww img "$DEFAULT_WALLPAPER" --transition-type none
        fi
        ;;
    random)
        img=$(find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | shuf -n1)
        set_wallpaper "$img"
        ;;
    select)
        img=$(find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | fuzzel --dmenu -p "Wallpaper: ")
        set_wallpaper "$img"
        ;;
    *)
        if [[ -f "$1" ]]; then
            set_wallpaper "$1"
        else
            echo "Usage: wallpaper.sh {init|random|select|<path>}"
            exit 1
        fi
        ;;
esac
