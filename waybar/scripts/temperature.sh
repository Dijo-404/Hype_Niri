#!/usr/bin/env bash

set -u

CRITICAL_TEMP=80

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/ }
    printf '%s' "$value"
}

sensor_label() {
    local input="$1"
    local label_file="${input%_input}_label"

    if [ -r "$label_file" ]; then
        cat "$label_file" 2>/dev/null || basename "${input%_input}"
    else
        basename "${input%_input}"
    fi
}

print_sensor() {
    local input="$1"
    local chip="$2"
    local label

    label="$(sensor_label "$input")"
    printf '%s\t%s\t%s\n' "$input" "$chip" "$label"
}

find_sensor_for_chip() {
    local preferred_chip="$1"
    local hwmon
    local chip
    local input
    local label
    local preferred_label

    for hwmon in /sys/class/hwmon/hwmon*; do
        [ -d "$hwmon" ] || continue
        chip="$(cat "$hwmon/name" 2>/dev/null || true)"
        [ "$chip" = "$preferred_chip" ] || continue

        for preferred_label in "Package id 0" Tctl Tdie CPU Composite; do
            for input in "$hwmon"/temp*_input; do
                [ -r "$input" ] || continue
                label="$(sensor_label "$input")"
                if [ "$label" = "$preferred_label" ]; then
                    print_sensor "$input" "$chip"
                    return 0
                fi
            done
        done

        for input in "$hwmon"/temp*_input; do
            [ -r "$input" ] || continue
            print_sensor "$input" "$chip"
            return 0
        done
    done

    return 1
}

find_sensor() {
    local preferred_chip
    local hwmon
    local chip
    local input

    for preferred_chip in coretemp k10temp zenpower thinkpad acpitz; do
        find_sensor_for_chip "$preferred_chip" && return 0
    done

    for hwmon in /sys/class/hwmon/hwmon*; do
        [ -d "$hwmon" ] || continue
        chip="$(cat "$hwmon/name" 2>/dev/null || true)"
        for input in "$hwmon"/temp*_input; do
            [ -r "$input" ] || continue
            print_sensor "$input" "${chip:-hwmon}"
            return 0
        done
    done

    return 1
}

emit_missing() {
    printf '{"text": "", "tooltip": "temperature sensor unavailable", "class": "missing", "percentage": 0}\n'
}

if ! IFS=$'\t' read -r sensor_path chip label < <(find_sensor); then
    emit_missing
    exit 0
fi

raw_temp="$(cat "$sensor_path" 2>/dev/null || true)"
if [[ ! "$raw_temp" =~ ^-?[0-9]+$ ]]; then
    emit_missing
    exit 0
fi

temp_c=$(((raw_temp + 500) / 1000))
percentage=$((temp_c * 100 / CRITICAL_TEMP))
[ "$percentage" -lt 0 ] && percentage=0
[ "$percentage" -gt 100 ] && percentage=100

class=""
[ "$temp_c" -ge "$CRITICAL_TEMP" ] && class="critical"

tooltip="Temperature: ${temp_c}°C"
if [ -n "${chip:-}" ]; then
    tooltip="$tooltip ($(json_escape "$chip")"
    [ -n "${label:-}" ] && tooltip="$tooltip $(json_escape "$label")"
    tooltip="$tooltip)"
fi

printf '{"text": "%s°", "tooltip": "%s", "class": "%s", "percentage": %d}\n' \
    "$temp_c" "$tooltip" "$class" "$percentage"
