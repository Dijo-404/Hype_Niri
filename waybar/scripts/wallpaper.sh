#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Pointer to the last-chosen wallpaper -- persists across reboot, read by hyprlock.
STATE_DIR="$HOME/.local/state/hypr"
CURRENT_LINK="$STATE_DIR/current_wallpaper"
mkdir -p "$STATE_DIR"

TRANSITION_TYPE="fade"
TRANSITION_STEP=90
TRANSITION_FPS=120
TRANSITION_DURATION=1

find_wallpaper() {
    [[ -d "$WALLPAPER_DIR" ]] || return 1
    find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | head -n 1
}

ensure_current_wallpaper() {
    [[ -f "$CURRENT_LINK" ]] && return 0

    local fallback
    fallback="$(find_wallpaper)"
    [[ -f "$fallback" ]] || return 1
    ln -sfn "$fallback" "$CURRENT_LINK"
}

start_daemon() {
    # Silent exit if awww is missing -- startup calls must not spam errors.
    command -v awww >/dev/null 2>&1 || return 1

    if ! pgrep -x awww-daemon >/dev/null; then
        local daemon_pid
        awww-daemon --format xrgb >/dev/null 2>&1 &
        daemon_pid=$!
        sleep 0.3
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            wait "$daemon_pid" 2>/dev/null || true
        fi
    fi

    pgrep -x awww-daemon >/dev/null || return 1
}

apply_wallpaper() {
    local img="$1"
    local transition="${2:-$TRANSITION_TYPE}"

    start_daemon || return 0
    awww img "$img" \
        --transition-type "$transition" \
        --transition-step "$TRANSITION_STEP" \
        --transition-fps "$TRANSITION_FPS" \
        --transition-duration "$TRANSITION_DURATION"
}

set_wallpaper() {
    local img="$1"
    if [[ -f "$img" ]]; then
        ln -sfn "$img" "$CURRENT_LINK"
        apply_wallpaper "$img"
    fi
}

case "${1:-}" in
    init)
        ensure_current_wallpaper || exit 0
        apply_wallpaper "$CURRENT_LINK" none
        ;;
    current|restore|sync)
        ensure_current_wallpaper || exit 0
        apply_wallpaper "$CURRENT_LINK" none
        ;;
    random)
        [[ -d "$WALLPAPER_DIR" ]] || exit 0
        img=$(find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | shuf -n1)
        set_wallpaper "$img"
        ;;
    select)
        [[ -d "$WALLPAPER_DIR" ]] || exit 0
        img=$(find "$WALLPAPER_DIR" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | fuzzel --dmenu -p "Wallpaper: ")
        set_wallpaper "$img"
        ;;
    *)
        if [[ -f "$1" ]]; then
            set_wallpaper "$1"
        else
            echo "Usage: wallpaper.sh {init|current|random|select|<path>}"
            exit 1
        fi
        ;;
esac
