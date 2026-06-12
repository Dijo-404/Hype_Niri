#!/usr/bin/env bash

pidof hyprlock >/dev/null 2>&1 && exit 0

"$HOME/.config/waybar/scripts/wallpaper.sh" current >/dev/null 2>&1 || true
hyprlock --immediate >/dev/null 2>&1 &

for _ in $(seq 1 40); do
    pidof hyprlock >/dev/null 2>&1 && exit 0
    sleep 0.05
done
