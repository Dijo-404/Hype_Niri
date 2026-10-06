#!/usr/bin/env bash

umask 077
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
if [ ! -d "$RUNTIME_DIR" ] || [ ! -w "$RUNTIME_DIR" ] || [ ! -O "$RUNTIME_DIR" ] || [ -L "$RUNTIME_DIR" ]; then
    RUNTIME_DIR="/tmp/hype-niri-$UID"
    [ ! -L "$RUNTIME_DIR" ] || exit 1
    if [ ! -d "$RUNTIME_DIR" ]; then
        mkdir -m 700 -- "$RUNTIME_DIR" 2>/dev/null || [ -d "$RUNTIME_DIR" ] || exit 1
    fi
    [ -d "$RUNTIME_DIR" ] && [ -O "$RUNTIME_DIR" ] && [ ! -L "$RUNTIME_DIR" ] || exit 1
    chmod 700 -- "$RUNTIME_DIR" || exit 1
fi
