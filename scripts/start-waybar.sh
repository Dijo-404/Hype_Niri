#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${WAYBAR_CONFIG:-$HOME/.config/waybar/config.jsonc}"
source "${BASH_SOURCE[0]%/*}/runtime-dir.sh"
GENERATED_CONFIG="$RUNTIME_DIR/hype-waybar-multi-output.json"
exec 9>"$RUNTIME_DIR/hype-waybar.lock"
flock -w 3 9 || exit 0
pgrep -u "$UID" -x waybar >/dev/null 2>&1 && exit 0

launch_waybar() {
    local config_file="$1"

    exec env GTK_THEME="${GTK_THEME:-Adwaita:dark}" waybar --config "$config_file"
}

connected_outputs() {
    local outputs_json="$1"

    jq -c '
        [
            to_entries[]
            | .value as $output
            | select($output.current_mode != null)
            | ($output.name // .key)
        ]
        | reduce .[] as $name ([]; if index($name) then . else . + [$name] end)
    ' <<<"$outputs_json"
}

build_multi_output_config() {
    local outputs="$1"

    jq --argjson outputs "$outputs" '
        if type == "array" then
            .
        elif type == "object" then
            . as $base
            | $outputs
            | map(($base | del(.output)) + {output: .})
        else
            .
        end
    ' "$CONFIG_FILE"
}

[ -r "$CONFIG_FILE" ] || launch_waybar "$CONFIG_FILE"

if ! command -v niri >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    launch_waybar "$CONFIG_FILE"
fi

if ! outputs_json="$(niri msg --json outputs 2>/dev/null)"; then
    launch_waybar "$CONFIG_FILE"
fi

if ! outputs="$(connected_outputs "$outputs_json" 2>/dev/null)"; then
    launch_waybar "$CONFIG_FILE"
fi

output_count="$(jq 'length' <<<"$outputs" 2>/dev/null || printf '0')"
if [ "$output_count" -lt 2 ]; then
    launch_waybar "$CONFIG_FILE"
fi

tmp_config="$(mktemp "$RUNTIME_DIR/.hype-waybar.XXXXXX")"
trap 'rm -f "$tmp_config"' EXIT
if build_multi_output_config "$outputs" >"$tmp_config"; then
    mv -f -- "$tmp_config" "$GENERATED_CONFIG"
    launch_waybar "$GENERATED_CONFIG"
fi

rm -f -- "$tmp_config"
launch_waybar "$CONFIG_FILE"
