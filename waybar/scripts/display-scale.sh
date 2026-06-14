#!/usr/bin/env bash
set -euo pipefail

OUTPUT_SCALE="2.0"

command -v niri >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

outputs_json="$(niri msg --json outputs 2>/dev/null)" || exit 0
mapfile -t outputs < <(jq -r 'keys[]' <<<"$outputs_json" 2>/dev/null)

for output in "${outputs[@]}"; do
    [ -n "$output" ] || continue
    niri msg output "$output" scale "$OUTPUT_SCALE" >/dev/null 2>&1 || true
done
