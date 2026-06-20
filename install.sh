#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR=""
PHASE_TOTAL=15
PHASE_CURRENT=0

# Visual layout: 2-space indent, fixed inner box width (columns between borders).
INDENT="  "
BOX_W=60

_tmp_resources=()
cleanup_tmp() {
    local r
    for r in "${_tmp_resources[@]:-}"; do
        [ -e "$r" ] && rm -rf -- "$r" 2>/dev/null || true
    done
}
trap cleanup_tmp EXIT
trap 'echo; printf "  \033[0;31m✗\033[0m Installation interrupted\n"; exit 130' INT TERM

# Repeat a (possibly multi-byte) char N times.
_repeat() {
    local char="$1" count="$2" out="" i
    for ((i = 0; i < count; i++)); do out+="$char"; done
    printf '%s' "$out"
}

# Word-wrap plain text to a max visible width, one line per row.
_wrap_text() {
    local text="$1" max="$2" line="" word
    for word in $text; do
        if [ -z "$line" ]; then
            line="$word"
        elif [ "$(( ${#line} + 1 + ${#word} ))" -le "$max" ]; then
            line="$line $word"
        else
            printf '%s\n' "$line"
            line="$word"
        fi
    done
    if [ -n "$line" ]; then printf '%s\n' "$line"; fi
}

_box_top() {
    echo -e "${INDENT}${CYAN}╭$(_repeat '─' "$BOX_W")╮${NC}"
}

# Top border carrying a left-aligned tag, e.g. "╭─ Phase 12 / 15 ─────╮"
_box_top_tag() {
    local tag="$1" fill
    fill=$(( BOX_W - 3 - ${#tag} ))
    if [ "$fill" -lt 0 ]; then fill=0; fi
    echo -e "${INDENT}${CYAN}╭─ ${BOLD}${tag}${NC}${CYAN} $(_repeat '─' "$fill")╮${NC}"
}

_box_bottom() {
    echo -e "${INDENT}${CYAN}╰$(_repeat '─' "$BOX_W")╯${NC}"
}

# One content row: " text" left-aligned, padded, closed with a right border.
_box_line() {
    local text="$1" color="${2:-}" padlen
    padlen=$(( BOX_W - 1 - ${#text} ))
    if [ "$padlen" -lt 0 ]; then padlen=0; fi
    echo -e "${INDENT}${CYAN}│${NC} ${color}${text}${NC}$(_repeat ' ' "$padlen")${CYAN}│${NC}"
}

# Slim overall-progress bar (filled vs remaining), aligned under the box.
_progress_bar() {
    local current="$1" total="$2" barw pct filled empty
    barw=$(( BOX_W - 6 ))
    pct=$(( current * 100 / total ))
    filled=$(( current * barw / total ))
    empty=$(( barw - filled ))
    echo -e "${INDENT}${GREEN}$(_repeat '█' "$filled")${GREY}$(_repeat '░' "$empty")${NC}  ${BOLD}${pct}%${NC}"
}

print_header() {
    local title="$1" subtitle="${2:-}" line
    local maxtext=$(( BOX_W - 2 ))
    local in_phase=false
    if [ "$PHASE_CURRENT" -gt 0 ] && [ "$PHASE_CURRENT" -le "$PHASE_TOTAL" ]; then
        in_phase=true
    fi

    echo ""
    if $in_phase; then
        _box_top_tag "Phase ${PHASE_CURRENT} / ${PHASE_TOTAL}"
    else
        _box_top
    fi

    while IFS= read -r line; do
        _box_line "$line" "${BOLD}"
    done < <(_wrap_text "$title" "$maxtext")

    if [ -n "$subtitle" ]; then
        while IFS= read -r line; do
            _box_line "$line" "${GREY}"
        done < <(_wrap_text "$subtitle" "$maxtext")
    fi

    _box_bottom
    if $in_phase; then
        _progress_bar "$PHASE_CURRENT" "$PHASE_TOTAL"
    fi
    echo ""
}

print_step() {
    echo -e "${INDENT}${CYAN}▸${NC} $1"
}

print_warn() {
    echo -e "${INDENT}${YELLOW}▲${NC} $1"
}

print_error() {
    echo -e "${INDENT}${RED}✗${NC} $1"
}

print_done() {
    echo -e "${INDENT}${GREEN}✓${NC} $1"
}

run_phase() {
    shift  # drop the short label; the header now renders the full title
    PHASE_CURRENT=$((PHASE_CURRENT + 1))
    "$@"
}

confirm() {
    [ -t 0 ] || return 1
    echo ""
    while true; do
        read -rp "$(echo -e "${INDENT}${YELLOW}?${NC} $1 ${GREY}[y/n]${NC}") " response || return 1
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) print_warn "Please answer y or n." ;;
        esac
    done
}

save_install_log() {
    local install_log="$1"
    print_error "Package installation failed. Last 40 log lines:"
    tail -n 40 "$install_log" | sed 's/^/    /'

    if grep -Eqi 'xwayland-satellite|failed retrieving file|404 Not Found|Could not resolve host|Connection timed out|SSL certificate problem|invalid or corrupted package' "$install_log"; then
        print_warn "If xwayland-satellite failed, it is an official Arch extra package, not an AUR package."
        print_warn "Rerun this installer and allow the mirror refresh step, or refresh manually:"
        print_warn "  sudo reflector --protocol https --latest 30 --sort rate --save /etc/pacman.d/mirrorlist"
        print_warn "  sudo pacman -Syu"
        print_warn "  sudo pacman -S --needed xwayland-satellite"
    fi

    local persisted
    persisted="/tmp/hype-niri-install-$(date +%Y%m%d-%H%M%S).log"
    cp -- "$install_log" "$persisted" 2>/dev/null || true
    print_warn "Full install log saved to: $persisted"
}

check_internet() {
    if command -v curl &>/dev/null; then
        curl --connect-timeout 5 -fsS https://archlinux.org >/dev/null 2>&1
        return $?
    fi

    if command -v wget &>/dev/null; then
        wget --timeout=5 --spider -q https://archlinux.org >/dev/null 2>&1
        return $?
    fi

    print_warn "curl/wget not found; skipping network preflight"
    print_warn "Package installation will report any network errors"
    return 0
}

refresh_mirrors() {
    print_header "Mirror Refresh" "rank fresh HTTPS mirrors for faster downloads"

    if ! confirm "Refresh Arch mirrors before installing packages?"; then
        print_warn "Skipping mirror refresh"
        print_warn "If downloads fail with 404s or timeouts, rerun and allow this step."
        return 0
    fi

    local mirrorlist="/etc/pacman.d/mirrorlist"
    local backup="/etc/pacman.d/mirrorlist.hype-niri.bak"
    local mirror_tmp=""

    if [ -f "$mirrorlist" ]; then
        print_step "Backing up current mirrorlist to $backup..."
        sudo cp "$mirrorlist" "$backup" 2>/dev/null || print_warn "Could not back up current mirrorlist"
    fi

    if command -v reflector &>/dev/null; then
        print_step "Ranking fresh HTTPS mirrors with reflector..."
        if sudo reflector --protocol https --latest 30 --sort rate --save "$mirrorlist"; then
            print_done "Mirrorlist refreshed with reflector"
            print_step "Refreshing pacman package databases..."
            sudo pacman -Syy
            print_done "Package databases refreshed"
            return 0
        fi

        print_warn "reflector failed; falling back to Arch's mirrorlist service"
    fi

    mirror_tmp="$(mktemp)" || { print_error "Failed to create temp mirrorlist"; exit 1; }
    _tmp_resources+=("$mirror_tmp")

    print_step "Downloading fresh HTTPS mirrorlist from archlinux.org..."
    if command -v curl &>/dev/null; then
        if ! curl --connect-timeout 10 -fsSL 'https://archlinux.org/mirrorlist/?country=all&protocol=https&ip_version=4&use_mirror_status=on' -o "$mirror_tmp"; then
            print_error "Failed to download a fresh mirrorlist with curl"
            print_warn "Keeping the existing mirrorlist"
            exit 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget --timeout=10 -qO "$mirror_tmp" 'https://archlinux.org/mirrorlist/?country=all&protocol=https&ip_version=4&use_mirror_status=on'; then
            print_error "Failed to download a fresh mirrorlist with wget"
            print_warn "Keeping the existing mirrorlist"
            exit 1
        fi
    else
        print_error "curl or wget is required to refresh mirrors without reflector"
        print_warn "Install reflector or refresh /etc/pacman.d/mirrorlist manually, then rerun ./install.sh"
        exit 1
    fi

    if ! grep -q '^#Server = https://' "$mirror_tmp"; then
        print_error "Downloaded mirrorlist did not contain HTTPS mirrors"
        print_warn "Keeping the existing mirrorlist"
        exit 1
    fi

    sed -i 's/^#Server = https:/Server = https:/' "$mirror_tmp"
    sudo install -m 644 "$mirror_tmp" "$mirrorlist"
    print_done "Mirrorlist refreshed from Arch mirror status"

    print_step "Refreshing pacman package databases..."
    sudo pacman -Syy
    print_done "Package databases refreshed"
}

update_system_packages() {
    print_header "System Package Update" "refresh keyring and upgrade installed packages"

    if ! confirm "Update Arch keyring and system packages before installing?"; then
        print_warn "Skipping system update"
        print_warn "If package signatures or downloads fail, rerun and allow this step."
        return 0
    fi

    local update_log
    update_log="$(mktemp)" || { print_error "Failed to create temp log"; exit 1; }
    _tmp_resources+=("$update_log")

    print_step "Updating archlinux-keyring first..."
    if ! stdbuf -oL -eL sudo pacman -Sy --needed archlinux-keyring 2>&1 | tee "$update_log"; then
        save_install_log "$update_log"
        exit 1
    fi

    print_step "Updating system packages..."
    if ! stdbuf -oL -eL sudo pacman -Syu 2>&1 | tee -a "$update_log"; then
        save_install_log "$update_log"
        exit 1
    fi

    print_done "System packages updated"
}

ensure_yay() {
    if command -v yay &>/dev/null; then
        print_done "yay found"
        return 0
    fi

    print_error "yay (AUR helper) is required for AUR packages, but it is not installed."
    print_warn "Install yay with your preferred method, then rerun ./install.sh."
    print_warn "The installer does not clone AUR repos to bootstrap yay."
    exit 1
}

preflight() {
    print_header "Preflight Checks" "verify Arch and network before any changes"

    if ! command -v pacman &>/dev/null; then
        print_error "This script requires Arch Linux (pacman not found)"
        exit 1
    fi
    print_done "Arch Linux detected"

    if ! check_internet; then
        print_error "No internet connection"
        exit 1
    fi
    print_done "Network preflight complete"
}

install_packages() {
    print_header "Installing Packages" "official repo and AUR packages from pkglist.txt"

    if [ ! -f "$SCRIPT_DIR/pkglist.txt" ]; then
        print_error "pkglist.txt not found at $SCRIPT_DIR/pkglist.txt"
        exit 1
    fi

    local packages=()
    local pacman_packages=()
    local aur_packages=()
    local total
    local pkg
    local install_log

    mapfile -t packages < <(
        grep -v '^#' "$SCRIPT_DIR/pkglist.txt" | \
        grep -v '^$' | \
        awk '{print $1}'
    )

    total=${#packages[@]}
    print_step "Installing $total packages..."
    echo ""

    if [ "$total" -eq 0 ]; then
        print_error "No packages found in pkglist.txt"
        exit 1
    fi

    print_step "Package queue:"
    for i in "${!packages[@]}"; do
        printf "    [%3d/%3d] %s\n" "$((i + 1))" "$total" "${packages[$i]}"
    done
    echo ""

    print_step "Classifying packages..."
    for pkg in "${packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            pacman_packages+=("$pkg")
        else
            aur_packages+=("$pkg")
        fi
    done

    print_step "Pacman packages: ${#pacman_packages[@]}"
    print_step "AUR packages: ${#aur_packages[@]}"

    install_log="$(mktemp)" || { print_error "Failed to create temp log"; exit 1; }
    _tmp_resources+=("$install_log")

    if [ "${#pacman_packages[@]}" -gt 0 ]; then
        print_step "Installing official repository packages with pacman..."
        if ! stdbuf -oL -eL sudo pacman -S --needed --noconfirm "${pacman_packages[@]}" 2>&1 | tee "$install_log"; then
            save_install_log "$install_log"
            exit 1
        fi
    fi

    if [ "${#aur_packages[@]}" -gt 0 ]; then
        ensure_yay
        print_step "Installing AUR packages with yay..."
        if ! stdbuf -oL -eL yay -S --needed --noconfirm "${aur_packages[@]}" 2>&1 | tee -a "$install_log"; then
            save_install_log "$install_log"
            exit 1
        fi
    fi

    if [ "${#pacman_packages[@]}" -eq 0 ] && [ "${#aur_packages[@]}" -eq 0 ]; then
        print_error "No installable packages found in pkglist.txt"
        exit 1
    fi

    print_done "All packages installed"
}

backup_configs() {
    print_header "Backing Up Existing Configs" "saved to a timestamped folder in your home"

    BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

    local configs_to_backup=(
        "niri"
        "waybar"
        "alacritty"
        "fuzzel"
        "mako"
        "fastfetch"
        "wlogout"
        "hypr"
    )

    local files_to_backup=(
        "$HOME/.zshrc"
        "$HOME/.p10k.zsh"
    )

    local has_existing=false
    for config in "${configs_to_backup[@]}"; do
        if [ -d "$HOME/.config/$config" ]; then
            has_existing=true
            break
        fi
    done
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            has_existing=true
            break
        fi
    done

    if $has_existing; then
        print_warn "Existing configs found"
        if confirm "Back up existing configs to $BACKUP_DIR?"; then
            mkdir -p "$BACKUP_DIR"
            for config in "${configs_to_backup[@]}"; do
                if [ -d "$HOME/.config/$config" ]; then
                    cp -r "$HOME/.config/$config" "$BACKUP_DIR/"
                    print_done "Backed up $config"
                fi
            done
            [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
            [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$BACKUP_DIR/.bashrc"
            [ -f "$HOME/.p10k.zsh" ] && cp "$HOME/.p10k.zsh" "$BACKUP_DIR/.p10k.zsh"
            [ -d "$HOME/.local/share/nautilus" ] && \
                cp -r "$HOME/.local/share/nautilus" "$BACKUP_DIR/nautilus-share"
            [ -d "$HOME/.config/nautilus" ] && \
                cp -r "$HOME/.config/nautilus" "$BACKUP_DIR/nautilus-config"
            print_done "Backup saved to $BACKUP_DIR"
        else
            print_error "Backup declined. Existing configs will not be overwritten."
            exit 1
        fi
    else
        print_done "No existing configs to back up"
    fi
}

copy_configs() {
    print_header "Copying Configurations" "niri, waybar, terminal, theming and dotfiles"

    mkdir -p "$HOME/.config"

    local configs=(
        "niri"
        "waybar"
        "alacritty"
        "fuzzel"
        "mako"
        "fastfetch"
        "wlogout"
        "hypr"
    )

    for config in "${configs[@]}"; do
        if [ -d "$SCRIPT_DIR/$config" ]; then
            local tmp="$HOME/.config/$config.new.$$"
            rm -rf "$tmp"
            cp -r "$SCRIPT_DIR/$config" "$tmp"
            rm -rf "$HOME/.config/$config"
            mv "$tmp" "$HOME/.config/$config"
            print_done "Copied $config -> ~/.config/$config"
        fi
    done

    chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null || true
    print_done "Made waybar scripts executable"

    if [ -d "$HOME/.config/waybar/colors" ]; then
        print_done "Waybar colors directory present"
    else
        print_warn "Waybar colors directory missing"
    fi

    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/Pictures/Wallpapers"
    if [ -d "$SCRIPT_DIR/Wallpapers" ] && [ "$(ls -A "$SCRIPT_DIR/Wallpapers" 2>/dev/null)" ]; then
        cp -r "$SCRIPT_DIR/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
        print_done "Copied wallpapers -> ~/Pictures/Wallpapers"
    else
        print_warn "No wallpapers found in source directory"
    fi

    mkdir -p "$HOME/.local/state/niri"
    if [ ! -e "$HOME/.local/state/niri/current_wallpaper" ]; then
        local seed_wallpaper
        seed_wallpaper="$(find "$HOME/Pictures/Wallpapers" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | head -n 1)"
        if [ -n "$seed_wallpaper" ] && [ -f "$seed_wallpaper" ]; then
            ln -sfn "$seed_wallpaper" "$HOME/.local/state/niri/current_wallpaper"
            print_done "Seeded wallpaper pointer -> ~/.local/state/niri/current_wallpaper"
        else
            print_warn "No wallpaper available to seed current_wallpaper"
        fi
    fi

    mkdir -p "$HOME/.cache/cliphist"

    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/blueman.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Hidden=true
EOF
    print_done "Suppressed blueman tray autostart"
}

setup_shell() {
    print_header "Setting Up Zsh" "zsh, powerlevel10k and fzf-tab"

    local current_shell

    print_step "Checking fzf-tab plugin..."
    if [ -f /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ] || \
       [ -f "$HOME/.zsh/fzf-tab/fzf-tab.plugin.zsh" ]; then
        print_done "fzf-tab available"
    else
        print_warn "fzf-tab not found -- ensure the 'fzf-tab' package installed from pkglist.txt"
    fi

    if [ -f "$SCRIPT_DIR/zsh/.zshrc" ]; then
        cp "$SCRIPT_DIR/zsh/.zshrc" "$HOME/.zshrc"
        print_done "Copied .zshrc -> ~/.zshrc"
    fi

    if [ -f "$SCRIPT_DIR/zsh/.p10k.zsh" ]; then
        cp "$SCRIPT_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
        print_done "Copied .p10k.zsh -> ~/.p10k.zsh"
    fi

    current_shell=$(basename "$SHELL")
    if [ "$current_shell" != "zsh" ]; then
        if confirm "Change default shell to zsh?"; then
            chsh -s /usr/bin/zsh
            print_done "Default shell changed to zsh"
            print_warn "Log out and back in for this to take effect"
        fi
    else
        print_done "Zsh is already the default shell"
    fi
}

setup_gtk() {
    print_header "GTK Theme Setup" "dark GTK, Qt and icon theming"

    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-application-prefer-dark-theme=true
EOF
    print_done "Created GTK 3 settings"

    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-application-prefer-dark-theme=true
EOF
    print_done "Created GTK 4 settings"

    mkdir -p "$HOME/.config/qt5ct"
    mkdir -p "$HOME/.config/qt6ct"
    cat > "$HOME/.config/qt5ct/conf" << 'EOF'
[General]
icon_theme=Papirus-Dark
standard_dialogs=default
EOF
    cp "$HOME/.config/qt5ct/conf" "$HOME/.config/qt6ct/conf"
    print_done "Created Qt5/Qt6 theme settings"

    if command -v papirus-folders &>/dev/null; then
        print_step "Setting Papirus-Dark folder color to grey..."
        if papirus-folders -C grey --theme Papirus-Dark; then
            print_done "Set Papirus-Dark folder color to grey"
        else
            print_warn "papirus-folders failed -- folder color unchanged"
        fi
    else
        print_warn "papirus-folders not found -- install 'papirus-folders-catppuccin-git' from AUR to recolor folders"
    fi

    if command -v dconf &>/dev/null; then
        print_step "Applying dark theme via dconf..."
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/icon-theme "'Papirus-Dark'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/cursor-theme "'Adwaita'" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/cursor-size "24" 2>/dev/null || true
        dconf write /org/gnome/desktop/interface/font-name "'JetBrainsMono Nerd Font 10'" 2>/dev/null || true
        print_done "Dark theme applied via dconf"
    elif command -v gsettings &>/dev/null; then
        print_step "Applying dark theme via gsettings..."
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 10' 2>/dev/null || true
        print_done "Dark theme applied via gsettings"
    else
        print_warn "Neither dconf nor gsettings found; GTK settings.ini files will still apply"
    fi
}

setup_desktop_integrations() {
    print_header "Desktop Integration Setup" "initialize XDG user directories"

    if command -v xdg-user-dirs-update &>/dev/null; then
        xdg-user-dirs-update
        print_done "XDG user directories initialized"
    else
        print_warn "xdg-user-dirs-update not found"
    fi
}

enable_system_service_now() {
    local service="$1"
    local label="${service%.service}"
    local unit_state

    unit_state="$(systemctl list-unit-files "$service" --no-legend 2>/dev/null || true)"
    if [ -z "$unit_state" ]; then
        print_warn "System service unit not found: $service"
        return 1
    fi

    if sudo systemctl enable --now "$service" >/dev/null 2>&1; then
        print_done "Enabled + started system service: $label"
        return 0
    fi

    if sudo systemctl enable "$service" >/dev/null 2>&1; then
        print_warn "Enabled system service but could not start now: $label"
    else
        print_warn "Failed to enable system service: $label"
    fi

    return 1
}

enable_user_service() {
    local service="$1"
    local start_now="${2:-later}"
    local label="${service%.service}"
    local unit_state

    unit_state="$(systemctl --user list-unit-files "$service" --no-legend 2>/dev/null || true)"
    if [ -z "$unit_state" ]; then
        print_warn "User service unit not found: $service"
        return 1
    fi

    if [ "$start_now" = "now" ]; then
        if systemctl --user enable --now "$service" >/dev/null 2>&1; then
            print_done "Enabled + started user service: $label"
            return 0
        fi

        if systemctl --user enable "$service" >/dev/null 2>&1; then
            print_warn "Enabled user service but could not start now: $label"
        else
            print_warn "Failed to enable user service: $label"
        fi
    elif systemctl --user enable "$service" >/dev/null 2>&1; then
        print_done "Enabled user service: $label"
        return 0
    else
        print_warn "Failed to enable user service: $label"
    fi

    return 1
}

setup_system() {
    print_header "System Configuration" "services, display manager and pacman tuning (sudo)"

    if [ -f /etc/pacman.conf ]; then
        print_step "Tuning pacman output..."
        sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf 2>/dev/null || true
        sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf 2>/dev/null || true
        if grep -q '^#ParallelDownloads' /etc/pacman.conf; then
            sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 6/' /etc/pacman.conf 2>/dev/null || true
        elif grep -q '^ParallelDownloads' /etc/pacman.conf; then
            sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 6/' /etc/pacman.conf 2>/dev/null || true
        else
            printf '\nParallelDownloads = 6\n' | sudo tee -a /etc/pacman.conf >/dev/null
        fi
        if ! grep -q '^ILoveCandy$' /etc/pacman.conf; then
            sudo sed -i '/^Color$/a ILoveCandy' /etc/pacman.conf 2>/dev/null || printf '\nILoveCandy\n' | sudo tee -a /etc/pacman.conf >/dev/null
        fi
        print_done "Pacman output tuned"
    fi

    if confirm "Set up ly as display manager?"; then
        sudo systemctl daemon-reload >/dev/null 2>&1 || true
        local installed_units
        installed_units=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}')

        if ! echo "$installed_units" | grep -q '^ly\.service$'; then
            print_warn "ly.service not found -- ly may not be installed correctly"
            print_warn "Try: sudo pacman -S ly && sudo systemctl daemon-reload"
        else
            for dm in sddm gdm lightdm greetd; do
                if echo "$installed_units" | grep -q "^${dm}\.service$"; then
                    if systemctl is-enabled "$dm" &>/dev/null; then
                        sudo systemctl disable "$dm" >/dev/null 2>&1 && print_step "Disabled $dm"
                    fi
                fi
            done

            if sudo systemctl enable ly >/dev/null 2>&1; then
                print_done "Enabled ly display manager"
            else
                print_warn "Failed to enable ly -- run 'sudo systemctl enable ly' manually"
            fi
        fi
    fi

    print_step "Installing Polkit rules (NetworkManager)..."
    if [ -d "$SCRIPT_DIR/polkit" ] && [ "$(ls -A "$SCRIPT_DIR/polkit" 2>/dev/null)" ]; then
        sudo cp -r "$SCRIPT_DIR/polkit/"*.rules /etc/polkit-1/rules.d/ 2>/dev/null || true
        print_done "Polkit rules applied"
    fi

    if [ ! -f /etc/pam.d/hyprlock ]; then
        printf '#%%PAM-1.0\nauth include login\n' | sudo tee /etc/pam.d/hyprlock >/dev/null
        print_done "Created /etc/pam.d/hyprlock"
    else
        print_done "hyprlock PAM config present"
    fi

    print_step "Enabling system services..."

    local system_services=(
        "NetworkManager.service"
        "bluetooth.service"
        "docker.service"
        "power-profiles-daemon.service"
    )

    for service in "${system_services[@]}"; do
        enable_system_service_now "$service" || true
    done

    if command -v docker >/dev/null 2>&1 && getent group docker >/dev/null 2>&1; then
        local current_user
        current_user="${SUDO_USER:-${USER:-$(id -un)}}"

        if id -nG "$current_user" 2>/dev/null | grep -qw docker; then
            print_done "User $current_user is already in docker group"
        elif confirm "Add $current_user to docker group? This requires logging out and back in."; then
            if sudo usermod -aG docker "$current_user"; then
                print_done "Added $current_user to docker group"
                print_warn "Log out and back in before running Docker without sudo"
            else
                print_warn "Could not add $current_user to docker group"
            fi
        else
            print_warn "Docker group setup skipped -- use sudo docker or add your user later"
        fi
    fi

    local start_now_user_services=(
        "pipewire.service"
        "pipewire-pulse.service"
        "wireplumber.service"
    )

    for service in "${start_now_user_services[@]}"; do
        enable_user_service "$service" now || true
    done

    enable_user_service "hypridle.service" later || \
        print_warn "Niri startup will still try to launch hypridle directly as a fallback"
    print_done "System services configured"
}

setup_logind() {
    print_header "Lid Switch Behavior" "suspend on lid close, stay awake while docked"

    if ! confirm "Configure systemd-logind to suspend on lid close (but keep running when an external monitor is connected)?"; then
        print_warn "Lid switch setup skipped"
        return 0
    fi

    local conf_dir=/etc/systemd/logind.conf.d
    local conf_file="$conf_dir/10-hype-niri-lid.conf"

    sudo mkdir -p "$conf_dir"
    sudo tee "$conf_file" >/dev/null << 'EOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
# Docked (external monitor): don't suspend; niri blanks the built-in panel.
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=yes
HoldoffTimeoutSec=0s
InhibitDelayMaxSec=5
EOF
    print_done "Wrote $conf_file"

    print_warn "Lid switch changes will apply after reboot"
    print_warn "Skipping systemd-logind restart to avoid blanking the current session"
}

setup_firewall() {
    print_header "Firewall Setup" "ufw with sensible desktop defaults"

    if ! command -v ufw &>/dev/null; then
        print_warn "ufw not installed -- skipping firewall setup"
        return 0
    fi

    if ! confirm "Configure ufw with desktop defaults (deny incoming, allow outgoing)?"; then
        print_warn "Firewall setup skipped (you can run 'sudo ufw enable' later)"
        return 0
    fi

    print_step "Setting default policies..."
    sudo ufw --force reset >/dev/null 2>&1 || true
    sudo ufw default deny incoming   >/dev/null
    sudo ufw default allow outgoing  >/dev/null
    sudo ufw default allow routed    >/dev/null

    sudo ufw allow in on lo  >/dev/null
    sudo ufw allow out on lo >/dev/null
    sudo ufw logging low >/dev/null
    sudo ufw --force enable >/dev/null
    sudo systemctl enable ufw.service >/dev/null 2>&1 || true

    print_done "ufw enabled with desktop defaults"
    print_step "Current rules:"
    sudo ufw status verbose | sed 's/^/    /'
}

setup_cloudflare() {
    print_header "Cloudflare WARP" "optional DNS-over-HTTPS or full VPN"

    if ! command -v warp-cli &>/dev/null; then
        print_warn "warp-cli not installed -- skipping (install cloudflare-warp-bin if you want it)"
        return 0
    fi

    if ! confirm "Set up Cloudflare WARP (DNS-over-HTTPS by default, full VPN optional)?"; then
        print_warn "Cloudflare WARP setup skipped"
        return 0
    fi

    if ! systemctl is-active --quiet warp-svc; then
        if ! sudo systemctl enable --now warp-svc >/dev/null 2>&1; then
            print_warn "Could not start/enable warp-svc -- skipping WARP setup"
            print_warn "Retry later with: sudo systemctl enable --now warp-svc"
            return 0
        fi
        print_done "warp-svc started + enabled"
        sleep 1
    else
        print_done "warp-svc already running"
    fi

    if ! warp-cli --accept-tos status >/dev/null 2>&1; then
        if ! warp-cli --accept-tos registration new >/dev/null 2>&1; then
            print_warn "WARP registration failed (may need re-run after reboot)"
            print_warn "Manually retry with: warp-cli --accept-tos registration new"
            return 0
        fi
        print_done "Device registered with Cloudflare"
    fi

    echo ""
    echo "  Choose WARP mode:"
    echo "    1) DNS-over-HTTPS only (safest, no VPN tunnel)  [default]"
    echo "    2) Full WARP VPN (encrypted tunnel)"
    echo "    3) Skip for now (leave configured but disconnected)"
    read -rp "  Mode [1/2/3]: " mode_choice || mode_choice=""
    case "${mode_choice:-1}" in
        2)
            if warp-cli --accept-tos mode warp >/dev/null 2>&1; then
                print_done "Mode: WARP (VPN)"
            else
                print_warn "Failed to set WARP mode"
            fi
            ;;
        3) print_warn "WARP enabled but no mode set; run 'warp-cli mode doh' to switch later"; return 0 ;;
        *)
            if warp-cli --accept-tos mode doh >/dev/null 2>&1; then
                print_done "Mode: DoH"
            else
                print_warn "Failed to set DoH mode"
            fi
            ;;
    esac

    if warp-cli --accept-tos connect >/dev/null 2>&1; then
        sleep 1
        local status
        status=$(warp-cli --accept-tos status 2>/dev/null || echo "unknown")
        print_done "WARP: $status"
    else
        print_warn "warp-cli connect failed -- check 'warp-cli status' manually"
    fi
}

validate() {
    print_header "Validating Installation" "check commands, configs, fonts and services"

    local all_ok=true
    local required_commands=(
        "niri"
        "waybar"
        "wlogout"
        "hyprlock"
        "hypridle"
        "mako"
        "fuzzel"
        "wl-paste"
        "cliphist"
        "gnome-keyring-daemon"
        "nm-applet"
        "blueman-applet"
        "notify-send"
        "brightnessctl"
        "powerprofilesctl"
        "loginctl"
    )
    local optional_commands=(
        "pavucontrol"
        "playerctl"
    )
    local cmd

    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            print_done "Command available: $cmd"
        else
            print_error "Missing command: $cmd"
            all_ok=false
        fi
    done

    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            print_done "Command available: $cmd"
        else
            print_warn "Optional command missing: $cmd"
        fi
    done

    if [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
        print_done "Polkit agent executable present"
    else
        print_error "Missing polkit agent: /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
        all_ok=false
    fi

    if command -v niri &>/dev/null; then
        if niri validate 2>/dev/null; then
            print_done "Niri config is valid"
        else
            print_warn "Niri config validation failed -- check ~/.config/niri/config.kdl"
            all_ok=false
        fi
    else
        print_warn "niri not found in PATH (may need a reboot)"
    fi

    local critical_files=(
        "$HOME/.config/niri/config.kdl"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/waybar/style.css"
        "$HOME/.config/waybar/scripts/brightness-control.sh"
        "$HOME/.config/waybar/scripts/caffeine-control.sh"
        "$HOME/.config/waybar/scripts/display-scale.sh"
        "$HOME/.config/waybar/scripts/fullscreen-toggle.sh"
        "$HOME/.config/waybar/scripts/lock-screen.sh"
        "$HOME/.config/waybar/scripts/lock.sh"
        "$HOME/.config/waybar/scripts/mic-control.sh"
        "$HOME/.config/waybar/scripts/monitor-refresh.sh"
        "$HOME/.config/waybar/scripts/open-drives.sh"
        "$HOME/.config/waybar/scripts/power-profile.sh"
        "$HOME/.config/waybar/scripts/prepare-sleep.sh"
        "$HOME/.config/waybar/scripts/start-tray-applets.sh"
        "$HOME/.config/waybar/scripts/start-waybar.sh"
        "$HOME/.config/waybar/scripts/suspend-now.sh"
        "$HOME/.config/waybar/scripts/temperature-control.sh"
        "$HOME/.config/waybar/scripts/volume-control.sh"
        "$HOME/.config/waybar/scripts/wallpaper.sh"
        "$HOME/.config/alacritty/alacritty.toml"
        "$HOME/.config/fuzzel/fuzzel.ini"
        "$HOME/.config/mako/config"
        "$HOME/.config/fastfetch/config.jsonc"
        "$HOME/.config/hypr/hyprlock.conf"
        "$HOME/.config/hypr/hypridle.conf"
        "$HOME/.config/wlogout/layout"
        "$HOME/.config/wlogout/style.css"
        "$HOME/.config/wlogout/icons/lock.png"
        "$HOME/.config/wlogout/icons/logout.png"
        "$HOME/.config/wlogout/icons/reboot.png"
        "$HOME/.config/wlogout/icons/shutdown.png"
        "$HOME/.config/wlogout/icons/suspend.png"
        "$HOME/.config/gtk-3.0/settings.ini"
        "$HOME/.config/gtk-4.0/settings.ini"
        "$HOME/.config/qt5ct/conf"
        "$HOME/.config/qt6ct/conf"
        "$HOME/.zshrc"
        "$HOME/.p10k.zsh"
    )

    for f in "${critical_files[@]}"; do
        if [ -f "$f" ]; then
            print_done "$(basename "$f")"
        else
            print_error "Missing: $f"
            all_ok=false
        fi
    done

    local script
    for script in "$HOME/.config/waybar/scripts/"*.sh; do
        [ -e "$script" ] || continue
        if [ -x "$script" ]; then
            print_done "Script executable: $(basename "$script")"
        else
            print_error "Script not executable: $script"
            all_ok=false
        fi

        if bash -n "$script" 2>/dev/null; then
            print_done "Script syntax: $(basename "$script")"
        else
            print_error "Script syntax failed: $script"
            all_ok=false
        fi
    done

    if command -v fc-match &>/dev/null; then
        local font_match
        font_match=$(fc-match -f '%{family}\n' 'Roboto' 2>/dev/null | head -n 1 || true)
        if [[ "$font_match" == *"Roboto"* ]]; then
            print_done "Font: Roboto"
        else
            print_warn "Roboto font not resolving -- install ttf-roboto"
        fi

        font_match=$(fc-match -f '%{family}\n' 'Material Design Icons' 2>/dev/null | head -n 1 || true)
        if [[ "$font_match" == *"Material Design Icons"* ]]; then
            print_done "Font: Material Design Icons"
        else
            print_warn "Material Design Icons font not resolving -- install ttf-material-design-icons-webfont"
        fi
    else
        print_warn "fontconfig not found -- cannot validate Waybar fonts"
    fi

    local unit
    local unit_state
    for unit in NetworkManager.service bluetooth.service docker.service power-profiles-daemon.service; do
        unit_state="$(systemctl list-unit-files "$unit" --no-legend 2>/dev/null || true)"
        if [ -n "$unit_state" ]; then
            if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
                print_done "System service enabled: ${unit%.service}"
            else
                print_warn "System service not enabled: ${unit%.service}"
            fi

            if systemctl is-active --quiet "$unit" 2>/dev/null; then
                print_done "System service running: ${unit%.service}"
            else
                print_warn "System service not running yet: ${unit%.service}"
            fi
        else
            print_warn "System service unit unavailable: $unit"
        fi
    done

    if systemctl --user show-environment >/dev/null 2>&1; then
        for unit in pipewire.service pipewire-pulse.service wireplumber.service hypridle.service; do
            unit_state="$(systemctl --user list-unit-files "$unit" --no-legend 2>/dev/null || true)"
            if [ -n "$unit_state" ]; then
                if systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
                    print_done "User service enabled: ${unit%.service}"
                else
                    print_warn "User service not enabled: ${unit%.service}"
                fi
            else
                print_warn "User service unit unavailable: $unit"
            fi
        done
    else
        print_warn "User systemd manager unavailable; skipping live user-service validation"
    fi

    if $all_ok; then
        echo ""
        echo -e "${GREEN}${BOLD}  All files in place!${NC}"
        return 0
    fi

    return 1
}

cleanup_old_configs() {
    print_header "Clean Up Old Configs" "remove leftover Hyprland, rofi and dunst configs"

    if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
        print_warn "Found old Hyprland config at ~/.config/hypr/hyprland.conf"
        if confirm "Remove old hyprland.conf?"; then
            rm -f "$HOME/.config/hypr/hyprland.conf"
            print_done "Removed hyprland.conf"
        fi
    fi

    local old_configs=(
        "$HOME/.config/Kvantum"
        "$HOME/.config/rofi"
        "$HOME/.config/dunst"
    )

    for config in "${old_configs[@]}"; do
        if [ -d "$config" ]; then
            print_warn "Found old config: $config"
            if confirm "Remove $config?"; then
                rm -rf "$config"
                print_done "Removed $config"
            fi
        fi
    done

    if [ -d "$HOME/.config/nautilus" ] || [ -d "$HOME/.local/share/nautilus" ]; then
        print_warn "Found existing Nautilus state (view prefs, bookmarks, tags)"
        if confirm "Reset Nautilus so the new dark theme applies cleanly?"; then
            rm -rf "$HOME/.config/nautilus" "$HOME/.local/share/nautilus"
            if command -v dconf &>/dev/null; then
                dconf reset -f /org/gnome/nautilus/ 2>/dev/null || true
            fi
            print_done "Nautilus state cleared"
        fi
    fi
}

print_summary() {
    echo ""
    _box_top
    _box_line "✓  Installation Complete" "${BOLD}${GREEN}"
    _box_line "your Niri desktop is ready to use" "${GREY}"
    _box_bottom
    echo ""
    echo -e "  ${BOLD}Next steps${NC}"
    echo -e "    ${CYAN}1${NC}  Reboot your system"
    echo -e "    ${CYAN}2${NC}  Select ${BOLD}niri-session${NC} at the ly login screen"
    echo -e "    ${CYAN}3${NC}  Powerlevel10k is preconfigured (run ${BOLD}p10k configure${NC} to tweak)"
    echo -e "    ${CYAN}4${NC}  ${BOLD}Super+A${NC} app launcher  ${GREY}·${NC}  ${BOLD}Super+T${NC} terminal"
    echo ""
    echo -e "  ${BOLD}Key files${NC}"
    echo -e "    ${GREY}niri  ${NC}  ~/.config/niri/config.kdl"
    echo -e "    ${GREY}waybar${NC}  ~/.config/waybar/"
    echo -e "    ${GREY}zsh   ${NC}  ~/.zshrc"
    echo -e "    ${GREY}keys  ${NC}  $SCRIPT_DIR/keybindings.md"
    echo ""
}

prompt_reboot() {
    [ -t 0 ] || return 0

    if confirm "Restart now?"; then
        print_warn "Restarting now..."
        if ! systemctl reboot; then
            print_error "Could not restart automatically. Please reboot manually."
            return 1
        fi
    else
        print_warn "Restart skipped. Reboot when ready to start using Niri."
    fi
}

main() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "    ╦ ╦╦ ╦╔═╗╔═╗  ╔╗╔╦╦═╗╦"
    echo "    ╠═╣╚╦╝╠═╝║╣   ║║║║╠╦╝║"
    echo "    ╩ ╩ ╩ ╩  ╚═╝  ╝╚╝╩╩╚═╩"
    echo -e "${NC}"
    echo -e "  ${BOLD}Arch Linux + Niri Wayland Setup${NC}"
    echo -e "  ${GREY}monochrome theme · automated installer${NC}"
    echo ""
    echo -e "${INDENT}${CYAN}$(_repeat '─' "$BOX_W")${NC}"
    echo ""

    if ! confirm "Start installation?"; then
        echo -e "\n  ${YELLOW}Installation cancelled.${NC}\n"
        exit 0
    fi

    run_phase "Preflight checks" preflight
    run_phase "Mirror refresh" refresh_mirrors
    run_phase "System package update" update_system_packages
    run_phase "Package installation" install_packages
    run_phase "Config backup" backup_configs
    run_phase "Old config cleanup" cleanup_old_configs
    run_phase "Copy dotfiles" copy_configs
    run_phase "Zsh setup" setup_shell
    run_phase "GTK/Qt theme setup" setup_gtk
    run_phase "Desktop integrations" setup_desktop_integrations
    run_phase "System services" setup_system
    run_phase "Lid switch behavior" setup_logind
    run_phase "Firewall setup" setup_firewall
    run_phase "Cloudflare WARP" setup_cloudflare
    if run_phase "Validation" validate; then
        print_summary
        prompt_reboot
    else
        print_error "Validation failed; installation did not complete cleanly"
        exit 1
    fi
}

main "$@"
