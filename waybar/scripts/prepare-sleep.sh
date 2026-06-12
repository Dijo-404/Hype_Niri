#!/usr/bin/env bash

pidof hyprlock >/dev/null 2>&1 && exit 0

hyprlock --grace 0 --immediate-render --no-fade-in >/dev/null 2>&1 &

sleep 0.15
