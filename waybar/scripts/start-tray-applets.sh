#!/usr/bin/env bash
set -euo pipefail

export GTK_THEME="${GTK_THEME:-Adwaita:dark}"

start_once() {
    local process="$1"
    shift

    command -v "$1" >/dev/null 2>&1 || return 0
    pgrep -x "$process" >/dev/null 2>&1 && return 0

    "$@" >/dev/null 2>&1 &
}

# These are the live tray icons used for Wi-Fi and Bluetooth in Waybar.
start_once "nm-applet" nm-applet --indicator
start_once "blueman-applet" blueman-applet
