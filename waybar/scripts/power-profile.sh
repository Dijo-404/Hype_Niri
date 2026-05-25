#!/bin/bash

# Power Profile Menu Script for Waybar
# Uses fuzzel for dropdown selection

# If power-profiles-daemon is not installed, emit a benign JSON stub so
# waybar doesn't show garbage, then exit.
if ! command -v powerprofilesctl >/dev/null 2>&1; then
    [[ "${1:-}" != "menu" ]] && echo '{"text": "", "tooltip": "power-profiles-daemon not installed", "class": "missing"}'
    exit 0
fi

ID=2004

get_current_profile() {
    powerprofilesctl get
}

get_icon() {
    case $1 in
        "performance") echo "󰓅" ;;
        "balanced") echo "󰾅" ;;
        "power-saver") echo "󰾆" ;;
        *) echo "󰾅" ;;
    esac
}

get_name() {
    case $1 in
        "performance") echo "Performance" ;;
        "balanced") echo "Balanced" ;;
        "power-saver") echo "Power Saver" ;;
        *) echo "$1" ;;
    esac
}

send_notification() {
    profile=$1
    icon=$(get_icon "$profile")
    name=$(get_name "$profile")
    notify-send -r "$ID" \
        "$icon  Power Mode: $name"
}

if [[ "${1:-}" == "menu" ]]; then
    command -v fuzzel >/dev/null 2>&1 || exit 0
    # Show fuzzel menu
    options="󰓅 Performance\n󰾅 Balanced\n󰾆 Power Saver"
    choice=$(echo -e "$options" | fuzzel --dmenu -p "Power Profile")
    
    case "$choice" in
        *"Performance"*)
            powerprofilesctl set performance
            send_notification "performance"
            ;;
        *"Balanced"*)
            powerprofilesctl set balanced
            send_notification "balanced"
            ;;
        *"Power Saver"*)
            powerprofilesctl set power-saver
            send_notification "power-saver"
            ;;
    esac
    
    # Signal waybar to update
    pkill -RTMIN+16 waybar
else
    # Output for waybar
    current=$(get_current_profile)
    icon=$(get_icon "$current")
    
    # JSON output for waybar custom module
    echo "{\"text\": \"$icon\", \"tooltip\": \"Power Profile: $current\", \"class\": \"$current\"}"
fi
