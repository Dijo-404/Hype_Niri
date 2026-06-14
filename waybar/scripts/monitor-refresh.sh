#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${NIRI_CONFIG:-$HOME/.config/niri/config.kdl}"
OUTPUT_SCALE="2.0"
NOTIFY_ID=2006
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
[ -d "$RUNTIME_DIR" ] && [ -w "$RUNTIME_DIR" ] || RUNTIME_DIR="/tmp"
LOCK_FILE="$RUNTIME_DIR/hype-monitor-refresh.lock"

if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || exit 0
fi

notify() {
    local title="$1"
    local body="${2:-}"

    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -r "$NOTIFY_ID" "$title" "$body" 2>/dev/null || true
}

missing_commands() {
    local missing=()
    local cmd

    for cmd in niri jq fuzzel awk mktemp; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        notify "Monitor refresh unavailable" "Missing required command(s): ${missing[*]}"
        exit 1
    fi
}

trim() {
    local value="${1:-}"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

format_rate() {
    awk -v mhz="$1" 'BEGIN {
        hz = mhz / 1000
        value = sprintf("%.3f", hz)
        sub(/0+$/, "", value)
        sub(/\.$/, "", value)
        print value
    }'
}

kdl_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

get_outputs_json() {
    local output

    if ! output="$(niri msg --json outputs 2>&1)"; then
        notify "Could not read monitors" "$output"
        exit 1
    fi

    printf '%s' "$output"
}

build_monitor_options() {
    local json="$1"

    jq -r '
        to_entries[]
        | .value as $output
        | (
            if $output.current_mode == null then
                null
            else
                ($output.modes[$output.current_mode] // null)
            end
        ) as $mode
        | [
            $output.name,
            ($output.make // ""),
            ($output.model // ""),
            (if $mode == null then "" else ($mode.width | tostring) end),
            (if $mode == null then "" else ($mode.height | tostring) end),
            (if $mode == null then "" else ($mode.refresh_rate | tostring) end)
        ]
        | @tsv
    ' <<<"$json" | while IFS=$'\t' read -r name make model width height refresh; do
        local description
        local current

        description="$(trim "$make $model")"
        [ -n "$description" ] || description="Unknown display"

        if [ -n "$width" ] && [ -n "$height" ] && [ -n "$refresh" ]; then
            current="${width}x${height} @ $(format_rate "$refresh") Hz"
        else
            current="current mode unknown"
        fi

        printf '%s\t%s\t%s\n' "$name" "$current" "$description"
    done
}

build_mode_options() {
    local json="$1"
    local output_name="$2"

    jq -r --arg output "$output_name" '
        .[$output] as $selected
        | if $selected == null then
            empty
          else
            ($selected.current_mode // -1) as $current
            | $selected.modes
            | to_entries[]
            | [
                (.value.width | tostring),
                (.value.height | tostring),
                (.value.refresh_rate | tostring),
                (if .key == $current then "current" else "" end),
                (if .value.is_preferred then "preferred" else "" end)
            ]
            | @tsv
          end
    ' <<<"$json" | while IFS=$'\t' read -r width height refresh is_current is_preferred; do
        local rate
        local mode
        local label
        local status=""

        rate="$(format_rate "$refresh")"
        mode="${width}x${height}@${rate}"
        label="${width}x${height} @ ${rate} Hz"

        [ "$is_current" = "current" ] && status="current"
        if [ "$is_preferred" = "preferred" ]; then
            [ -n "$status" ] && status="$status, "
            status="${status}preferred"
        fi
        [ -n "$status" ] && status="[$status]"

        printf '%s\t%s %s\n' "$mode" "$label" "$status"
    done
}

choose_line() {
    local prompt="$1"
    local options="$2"
    local choice

    choice="$(printf '%s\n' "$options" | fuzzel --dmenu -p "$prompt" || true)"
    [ -n "$choice" ] || exit 0

    printf '%s' "$choice"
}

apply_mode() {
    local output_name="$1"
    local mode="$2"
    local output

    if ! output="$(niri msg output "$output_name" mode "$mode" 2>&1)"; then
        notify "Could not change refresh rate" "$output"
        exit 1
    fi
}

apply_scale() {
    local output_name="$1"
    local output

    if ! output="$(niri msg output "$output_name" scale "$OUTPUT_SCALE" 2>&1)"; then
        notify "Could not set display scale" "$output"
        exit 1
    fi
}

write_config_mode() {
    local output_name="$1"
    local mode="$2"
    local config_dir
    local tmp_file
    local output_kdl

    output_kdl="$(kdl_escape "$output_name")"
    config_dir="$(dirname "$CONFIG_FILE")"
    mkdir -p "$config_dir"
    tmp_file="$(mktemp "$config_dir/.config.kdl.XXXXXX")"

    if [ -f "$CONFIG_FILE" ]; then
        awk -v output="$output_kdl" -v mode="$mode" -v scale="$OUTPUT_SCALE" '
            BEGIN {
                in_output = 0
                seen_output = 0
                wrote_mode = 0
                wrote_scale = 0
            }

            /^[[:space:]]*output[[:space:]]+"/ {
                output_name = $0
                sub(/^[[:space:]]*output[[:space:]]+"/, "", output_name)
                if (output_name ~ /"[[:space:]]*\{[[:space:]]*$/) {
                    sub(/"[[:space:]]*\{[[:space:]]*$/, "", output_name)
                    if (output_name == output) {
                        in_output = 1
                        seen_output = 1
                        wrote_mode = 0
                        wrote_scale = 0
                        print
                        next
                    }
                }
            }

            in_output && /^[[:space:]]*mode[[:space:]]+"/ {
                indent = $0
                sub(/[^[:space:]].*/, "", indent)
                if (indent == "") {
                    indent = "    "
                }
                if (!wrote_mode) {
                    print indent "mode \"" mode "\""
                    wrote_mode = 1
                }
                next
            }

            in_output && /^[[:space:]]*scale[[:space:]]+/ {
                indent = $0
                sub(/[^[:space:]].*/, "", indent)
                if (indent == "") {
                    indent = "    "
                }
                if (!wrote_scale) {
                    print indent "scale " scale
                    wrote_scale = 1
                }
                next
            }

            in_output && /^[[:space:]]*}[[:space:]]*$/ {
                if (!wrote_mode) {
                    print "    mode \"" mode "\""
                    wrote_mode = 1
                }
                if (!wrote_scale) {
                    print "    scale " scale
                    wrote_scale = 1
                }
                in_output = 0
                print
                next
            }

            { print }

            END {
                if (!seen_output) {
                    print ""
                    print "output \"" output "\" {"
                    print "    mode \"" mode "\""
                    print "    scale " scale
                    print "}"
                }
            }
        ' "$CONFIG_FILE" >"$tmp_file"
    else
        {
            printf 'output "%s" {\n' "$output_kdl"
            printf '    mode "%s"\n' "$mode"
            printf '    scale %s\n' "$OUTPUT_SCALE"
            printf '}\n'
        } >"$tmp_file"
    fi

    if ! niri validate -c "$tmp_file" >/dev/null 2>&1; then
        rm -f "$tmp_file"
        notify "Could not save default refresh rate" "Edited config did not validate: $CONFIG_FILE"
        exit 1
    fi

    mv "$tmp_file" "$CONFIG_FILE"
}

main() {
    local outputs_json
    local monitor_options
    local monitor_choice
    local output_name
    local mode_options
    local mode_choice
    local mode

    missing_commands

    outputs_json="$(get_outputs_json)"
    monitor_options="$(build_monitor_options "$outputs_json")"
    if [ -z "$monitor_options" ]; then
        notify "No monitors found" "Niri did not report any connected outputs."
        exit 1
    fi

    monitor_choice="$(choose_line "Monitor" "$monitor_options")"
    output_name="${monitor_choice%%$'\t'*}"

    mode_options="$(build_mode_options "$outputs_json" "$output_name")"
    if [ -z "$mode_options" ]; then
        notify "No refresh rates found" "$output_name does not report selectable modes."
        exit 1
    fi

    mode_choice="$(choose_line "$output_name refresh" "$mode_options")"
    mode="${mode_choice%%$'\t'*}"

    apply_mode "$output_name" "$mode"
    apply_scale "$output_name"
    write_config_mode "$output_name" "$mode"
    notify "Monitor refresh saved" "$output_name is now $mode at ${OUTPUT_SCALE}x scale"
}

main "$@"
