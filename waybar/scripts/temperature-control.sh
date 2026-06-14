#!/usr/bin/env bash

set -euo pipefail

HWMON_ROOT="${HWMON_ROOT:-/sys/class/hwmon}"
THERMAL_ROOT="${THERMAL_ROOT:-/sys/class/thermal}"
WARNING_TEMP="${HYPE_NIRI_TEMP_WARNING:-70}"
CRITICAL_TEMP="${HYPE_NIRI_TEMP_CRITICAL:-80}"

[[ "$WARNING_TEMP" =~ ^[0-9]+$ ]] || WARNING_TEMP=70
[[ "$CRITICAL_TEMP" =~ ^[0-9]+$ ]] || CRITICAL_TEMP=80

best_score=-9999
best_temp=""
best_source=""

lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

read_first_line() {
    local file="$1"
    local value=""

    [ -r "$file" ] || return 1
    IFS= read -r value < "$file" || return 1
    printf '%s' "$value"
}

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/ }
    value=${value//$'\r'/ }
    printf '%s' "$value"
}

emit() {
    local text="$1"
    local tooltip="$2"
    local class="$3"

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
        "$(json_escape "$text")" \
        "$(json_escape "$tooltip")" \
        "$(json_escape "$class")"
}

to_celsius() {
    local raw="$1"

    raw=${raw//[[:space:]]/}
    [[ "$raw" =~ ^-?[0-9]+$ ]] || return 1

    if (( raw > 1000 || raw < -1000 )); then
        if (( raw < 0 )); then
            printf '%d\n' $(((raw - 500) / 1000))
        else
            printf '%d\n' $(((raw + 500) / 1000))
        fi
    else
        printf '%d\n' "$raw"
    fi
}

score_sensor() {
    local name
    local label
    local path
    local haystack
    local score=0

    name="$(lower "$1")"
    label="$(lower "$2")"
    path="$(lower "$3")"
    haystack="$name $label $path"

    if [[ "$haystack" =~ (nvme|iwlwifi|wifi|wireless|bat|battery|ucsi|usb|charger|adapter|amdgpu|radeon|nouveau|nvidia|gpu|drm) ]]; then
        score=$((score - 300))
    fi

    if [[ "$name" =~ (coretemp|k10temp|zenpower|cpu_thermal|x86_pkg_temp|fam15h_power) ]]; then
        score=$((score + 120))
    elif [[ "$name" =~ (acpitz|thermal|soc) ]]; then
        score=$((score + 20))
    fi

    if [[ "$label" =~ (package|tdie) ]]; then
        score=$((score + 90))
    elif [[ "$label" =~ (tctl|cpu) ]]; then
        score=$((score + 80))
    elif [[ "$label" =~ core ]]; then
        score=$((score + 40))
    elif [ -z "$label" ]; then
        score=$((score + 5))
    fi

    printf '%d\n' "$score"
}

consider_sensor() {
    local name="$1"
    local label="$2"
    local input_file="$3"
    local raw
    local temp
    local score
    local source

    raw="$(read_first_line "$input_file" 2>/dev/null || true)"
    temp="$(to_celsius "$raw" 2>/dev/null || true)"
    [ -n "$temp" ] || return 0

    if (( temp < -40 || temp > 150 )); then
        return 0
    fi

    score="$(score_sensor "$name" "$label" "$input_file")"
    source="$name"
    [ -n "$label" ] && source="$source / $label"

    if (( score > best_score )) || { (( score == best_score )) && { [ -z "$best_temp" ] || (( temp > best_temp )); }; }; then
        best_score="$score"
        best_temp="$temp"
        best_source="$source"
    fi
}

scan_hwmon() {
    local hwmon
    local input
    local name
    local label
    local base

    for hwmon in "$HWMON_ROOT"/hwmon*; do
        [ -d "$hwmon" ] || continue
        name="$(read_first_line "$hwmon/name" 2>/dev/null || printf 'hwmon')"

        for input in "$hwmon"/temp*_input; do
            [ -e "$input" ] || continue
            base="${input%_input}"
            label="$(read_first_line "${base}_label" 2>/dev/null || true)"
            consider_sensor "$name" "$label" "$input"
        done
    done
}

scan_thermal_zones() {
    local zone
    local name

    for zone in "$THERMAL_ROOT"/thermal_zone*; do
        [ -d "$zone" ] || continue
        [ -r "$zone/temp" ] || continue
        name="$(read_first_line "$zone/type" 2>/dev/null || printf 'thermal')"
        consider_sensor "$name" "$name" "$zone/temp"
    done
}

scan_hwmon
scan_thermal_zones

if [ -z "$best_temp" ] || (( best_score <= 0 )); then
    emit "--°" "Temperature unavailable" "missing"
    exit 0
fi

if (( best_temp >= CRITICAL_TEMP )); then
    temp_class="critical"
elif (( best_temp >= WARNING_TEMP )); then
    temp_class="warning"
else
    temp_class="normal"
fi

emit "${best_temp}°" "CPU temperature: ${best_temp}°C (${best_source})" "$temp_class"
