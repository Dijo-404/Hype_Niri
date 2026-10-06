#!/usr/bin/env bash

set -euo pipefail

command -v wpctl >/dev/null 2>&1 || exit 0
source "${BASH_SOURCE[0]%/*}/runtime-dir.sh"
exec 9>"$RUNTIME_DIR/hype-mic-control.lock"
flock -w 1 9 || exit 0

ID=2003

case "${1:-}" in
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || exit 0
        ;;
esac

mic_info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) || exit 0

command -v notify-send >/dev/null 2>&1 || exit 0

if [[ "$mic_info" == *MUTED* ]]; then
    notify-send -r "$ID" \
        "󰍭  Microphone Muted" 2>/dev/null || true
else
    notify-send -r "$ID" \
        "󰍬  Microphone Active" 2>/dev/null || true
fi
