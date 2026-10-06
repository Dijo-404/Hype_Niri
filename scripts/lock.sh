#!/usr/bin/env bash
set -euo pipefail

source "${BASH_SOURCE[0]%/*}/runtime-dir.sh"
exec 9>"$RUNTIME_DIR/hype-lock-screen.lock"
flock -n 9 || exit 0
pgrep -u "$UID" -x hyprlock >/dev/null 2>&1 && exit 0
"$HOME/.config/scripts/wallpaper.sh" ensure >/dev/null 2>&1 || true
flags=(--grace 0)
[[ "${1:-}" == "sleep" ]] && flags+=(--immediate-render --no-fade-in)
exec hyprlock "${flags[@]}"
