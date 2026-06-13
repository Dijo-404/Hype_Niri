#!/usr/bin/env bash
pidof hyprlock >/dev/null 2>&1 && exit 0
flags=(--grace 0)
[ "$1" = "sleep" ] && flags+=(--immediate-render --no-fade-in)
exec hyprlock "${flags[@]}"
