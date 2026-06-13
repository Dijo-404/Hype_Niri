#!/usr/bin/env bash

set -u

USER_NAME="${USER:-$(id -un 2>/dev/null || printf user)}"
MEDIA_DIR="/run/media/$USER_NAME"
DRIVES_DIR="$HOME/Drives"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
[ -d "$RUNTIME_DIR" ] && [ -w "$RUNTIME_DIR" ] || RUNTIME_DIR="/tmp"
LOCK_FILE="$RUNTIME_DIR/hype-open-drives.lock"

if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || exit 0
fi

notify() {
    local title="$1"
    local body="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body" 2>/dev/null || true
    fi
}

have_storage_tools() {
    local missing=()
    local cmd

    for cmd in findmnt lsblk udisksctl; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        notify "Drive mounting unavailable" "Missing required command(s): ${missing[*]}"
        return 1
    fi
}

is_mounted() {
    findmnt -rn -S "$1" >/dev/null 2>&1
}

settle_devices() {
    if command -v udevadm >/dev/null 2>&1; then
        udevadm settle --timeout=5 >/dev/null 2>&1 || true
    else
        sleep 0.2
    fi
}

mount_with_fallback() {
    local dev="$1"
    local fstype="$2"
    local output

    if is_mounted "$dev"; then
        return 0
    fi

    if output="$(udisksctl mount -b "$dev" 2>&1)"; then
        return 0
    fi

    if [ "$fstype" = "ntfs" ]; then
        if output="$(udisksctl mount -b "$dev" -o ro 2>&1)"; then
            notify "Mounted Windows volume read-only" "Windows left this NTFS volume dirty or hibernated. Run chkdsk and fully shut down Windows for write access."
            return 0
        fi
    fi

    notify "Could not mount $dev" "$output"
    return 1
}

unlock_luks_volumes() {
    local dev
    local child_count

    command -v gio >/dev/null 2>&1 || return 0

    while read -r dev; do
        [ -b "$dev" ] || continue

        child_count="$(lsblk -nrpo NAME "$dev" 2>/dev/null | wc -l)"
        if [ "$child_count" -gt 1 ]; then
            continue
        fi

        gio mount -d "$dev" >/dev/null 2>&1 || true
    done < <(lsblk -prno NAME,FSTYPE | awk '$2 == "crypto_LUKS" { print $1 }')
}

mount_unmounted_filesystems() {
    local dev
    local fstype
    local mountpoints

    while read -r dev fstype mountpoints; do
        [ -b "$dev" ] || continue
        [ -n "$fstype" ] || continue
        [ -z "${mountpoints:-}" ] || continue

        case "$fstype" in
            ntfs|exfat|btrfs|ext2|ext3|ext4|xfs)
                mount_with_fallback "$dev" "$fstype" || true
                ;;
        esac
    done < <(lsblk -prno NAME,FSTYPE,MOUNTPOINTS)
}

alias_for_mount() {
    local source="$1"
    local target="$2"
    local label

    label="$(lsblk -no LABEL "$source" 2>/dev/null | head -n 1)"
    printf '%s\n' "${label:-$(basename "$target")}"
}

sanitize_link_name() {
    local name="$1"

    name="${name//\//-}"
    name="${name//\\/-}"
    name="${name//$'\n'/ }"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [ -n "$name" ] || name="Drive"

    printf '%s\n' "$name"
}

create_drive_links() {
    local source
    local target
    local name
    local base_name
    local suffix
    local link_path
    local -A used_names=()

    mkdir -p "$DRIVES_DIR"
    find "$DRIVES_DIR" -maxdepth 1 -xtype l -delete 2>/dev/null || true

    while read -r source target; do
        case "$target" in
            "$MEDIA_DIR"/*)
                base_name="$(sanitize_link_name "$(alias_for_mount "$source" "$target")")"
                name="$base_name"
                suffix=2

                while [ -n "${used_names[$name]:-}" ] || { [ -e "$DRIVES_DIR/$name" ] && [ ! -L "$DRIVES_DIR/$name" ]; }; do
                    name="$base_name-$suffix"
                    suffix=$((suffix + 1))
                done

                used_names[$name]=1
                link_path="$DRIVES_DIR/$name"
                ln -sfnT "$target" "$link_path" 2>/dev/null || true
                ;;
        esac
    done < <(findmnt -rn -o SOURCE,TARGET)
}

open_file_manager() {
    command -v nautilus >/dev/null 2>&1 || {
        notify "Nautilus not found" "Install nautilus or open ~/Drives manually."
        return 0
    }

    if [ -d "$DRIVES_DIR" ]; then
        nautilus -w "$DRIVES_DIR" >/dev/null 2>&1 &
    else
        nautilus -w >/dev/null 2>&1 &
    fi
}

if have_storage_tools; then
    unlock_luks_volumes
    settle_devices
    mount_unmounted_filesystems
    settle_devices
    mount_unmounted_filesystems
    create_drive_links
fi
open_file_manager
