#!/usr/bin/env bash
set -euo pipefail

source "${BASH_SOURCE[0]%/*}/runtime-dir.sh"
state_file="$RUNTIME_DIR/hype-copilot.state"
exec 9>"$RUNTIME_DIR/hype-copilot.lock"
flock -x 9

# Each non-repeating Copilot press starts a short-lived worker. The second
# press replaces the first worker's token, cancelling its pending editor launch.
window_us=400000
token="${EPOCHREALTIME/./}"
previous=0
phase=""
if [ -f "$state_file" ]; then
    read -r previous phase < "$state_file" || true
fi
[[ "$previous" =~ ^[0-9]{1,18}$ ]] || previous=0
previous=$((10#$previous))
elapsed=$((token - previous))

if [[ "$phase" == double ]] && (( elapsed >= 0 && elapsed <= window_us )); then
    # Ignore an extra tap in the same double-press gesture.
    exit 0
elif [[ "$phase" == single ]] && (( elapsed >= 0 && elapsed <= window_us )); then
    action=double
else
    action=single
fi
printf '%s %s\n' "$token" "$action" > "$state_file"
flock -u 9

# Wait for a possible second press, and for key releases before blanking.
sleep 0.4
flock -x 9
read -r current current_action 2>/dev/null < "$state_file" || exit 0
[[ "$current" == "$token" && "$current_action" == "$action" ]] || exit 0

if [[ "$action" == double ]]; then
    # Retain the token briefly so a third press cannot launch the editor.
    exec 9>&-
    exec "${BASH_SOURCE[0]%/*}/copilot-display.sh" toggle
else
    rm -f -- "$state_file"
    # These binds also run while locked so the double press can restore displays.
    # A single press must never start an editor behind the lock screen.
    [[ ! -f "$RUNTIME_DIR/hype-copilot-displays.state" ]] || exit 0
    [[ -n "${XDG_SESSION_ID:-}" ]] || exit 0
    locked="$(loginctl show-session "$XDG_SESSION_ID" -p LockedHint --value)" || exit 0
    [[ "$locked" == no ]] || exit 0
    exec 9>&-
    exec code
fi
