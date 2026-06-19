#!/usr/bin/env bash
set -euo pipefail

command -v niri >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

scale_for_resolution() {
    local width="$1"
    local height="$2"
    local short

    [[ "$width" =~ ^[0-9]+$ ]] || { printf '1.0\n'; return; }
    [[ "$height" =~ ^[0-9]+$ ]] || { printf '1.0\n'; return; }

    if [ "$width" -lt "$height" ]; then
        short="$width"
    else
        short="$height"
    fi

    if [ "$short" -ge 1800 ]; then
        printf '2.0\n'
    elif [ "$short" -ge 1600 ]; then
        printf '1.5\n'
    else
        printf '1.0\n'
    fi
}

outputs_json="$(niri msg --json outputs 2>/dev/null)" || exit 0

while IFS=$'\t' read -r output width height; do
    [ -n "$output" ] || continue
    scale="$(scale_for_resolution "$width" "$height")"
    niri msg output "$output" scale "$scale" >/dev/null 2>&1 || true
done < <(
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
        | select($mode != null)
        | [$output.name, ($mode.width | tostring), ($mode.height | tostring)]
        | @tsv
    ' <<<"$outputs_json" 2>/dev/null
)
