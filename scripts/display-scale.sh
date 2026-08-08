#!/usr/bin/env bash
# Persist per-output scales via niri's included outputs.kdl; a runtime
# `niri msg output scale` is temporary and dropped on monitor reconnect.
set -euo pipefail

outputs_kdl="${XDG_CONFIG_HOME:-$HOME/.config}/niri/outputs.kdl"
reload=1
[ "${1:-}" = "--no-reload" ] && reload=0

command -v niri >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

mkdir -p "$(dirname "$outputs_kdl")"
[ -e "$outputs_kdl" ] || : > "$outputs_kdl"   # ensure the include target exists

scale_for_resolution() {
    local width="$1" height="$2" short

    [[ "$width" =~ ^[0-9]+$ ]] && [[ "$height" =~ ^[0-9]+$ ]] || { printf '1.0'; return; }
    if [ "$width" -lt "$height" ]; then short="$width"; else short="$height"; fi

    if [ "$short" -ge 1800 ]; then printf '2.0'
    elif [ "$short" -ge 1600 ]; then printf '1.5'
    else printf '1.0'
    fi
}

outputs_json="$(niri msg --json outputs 2>/dev/null)" || exit 0

tmp="$(mktemp "$(dirname "$outputs_kdl")/.outputs.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

while IFS=$'\t' read -r name width height; do
    [ -n "$name" ] || continue
    printf 'output "%s" {\n    scale %s\n}\n' "$name" "$(scale_for_resolution "$width" "$height")"
done < <(
    jq -r '
        to_entries[]
        | .value as $o
        | (if $o.current_mode == null then null else ($o.modes[$o.current_mode] // null) end) as $m
        | select($m != null)
        | [$o.name, ($m.width | tostring), ($m.height | tostring)]
        | @tsv
    ' <<<"$outputs_json" 2>/dev/null | sort
) > "$tmp"

# Rewrite + reload only when changed.
if [ -s "$tmp" ] && ! cmp -s "$tmp" "$outputs_kdl" 2>/dev/null; then
    mv -f "$tmp" "$outputs_kdl"
    [ "$reload" = 1 ] && niri msg action load-config-file >/dev/null 2>&1 || true
fi
