#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR=""
PHASE_TOTAL=13
PHASE_CURRENT=0

_tmp_resources=()
cleanup_tmp() {
    local r
    for r in "${_tmp_resources[@]:-}"; do
        [ -e "$r" ] && rm -rf -- "$r" 2>/dev/null || true
    done
}
trap cleanup_tmp EXIT
trap 'echo; printf "  \033[0;31mx\033[0m Installation interrupted\n"; exit 130' INT TERM

print_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}$1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "  ${GREEN}>>${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}!!${NC} $1"
}

print_error() {
    echo -e "  ${RED}x${NC} $1"
}

print_done() {
    echo -e "  ${GREEN}+${NC} $1"
}

print_progress() {
    local current="$1"
    local total="$2"
    local label="$3"
    local width=26
    local filled
    local percent
    local bar=""
    local i

    percent=$((current * 100 / total))
    filled=$((current * width / total))

    for ((i = 0; i < width; i++)); do
        if [ "$i" -lt "$filled" ]; then
            bar+="#"
        else
            bar+="-"
        fi
    done

    echo ""
    echo -e "  ${CYAN}Progress${NC} [${bar}] ${BOLD}${percent}%${NC}  (${current}/${total}) ${label}"
}

run_phase() {
    local label="$1"
    shift

    PHASE_CURRENT=$((PHASE_CURRENT + 1))
    print_progress "$PHASE_CURRENT" "$PHASE_TOTAL" "$label"
    "$@"
}

confirm() {
    echo ""
    read -rp "  $(echo -e "${YELLOW}?${NC}") $1 [Y/n] " response
    case "$response" in
        [nN][oO]|[nN]) return 1 ;;
        *) return 0 ;;
    esac
}

save_install_log() {
    local install_log="$1"
    print_error "Package installation failed. Last 40 log lines:"
    tail -n 40 "$install_log" | sed 's/^/    /'
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
    print_header "Preflight Checks"

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
    print_header "Installing Packages"

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
    print_header "Backing Up Existing Configs"

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
    print_header "Copying Configurations"

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
            rm -rf "$HOME/.config/$config"
            cp -r "$SCRIPT_DIR/$config" "$HOME/.config/$config"
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

    mkdir -p "$HOME/.local/state/hypr"
    if [ ! -e "$HOME/.local/state/hypr/current_wallpaper" ]; then
        local seed_wallpaper
        seed_wallpaper="$(find "$HOME/Pictures/Wallpapers" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | head -n 1)"
        if [ -n "$seed_wallpaper" ] && [ -f "$seed_wallpaper" ]; then
            ln -sfn "$seed_wallpaper" "$HOME/.local/state/hypr/current_wallpaper"
            print_done "Seeded wallpaper pointer -> ~/.local/state/hypr/current_wallpaper"
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
    print_header "Setting Up Zsh"

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
    print_header "GTK Theme Setup"

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
        print_step "Setting Papirus-Dark folder color to cat-mocha-grey..."
        if papirus-folders -C cat-mocha-grey --theme Papirus-Dark; then
            print_done "Set Papirus-Dark folder color to cat-mocha-grey"
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
    print_header "Desktop Integration Setup"

    if command -v xdg-user-dirs-update &>/dev/null; then
        xdg-user-dirs-update
        print_done "XDG user directories initialized"
    else
        print_warn "xdg-user-dirs-update not found"
    fi
}

setup_system() {
    print_header "System Configuration (requires sudo)"

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
        "NetworkManager"
        "bluetooth"
    )

    for service in "${system_services[@]}"; do
        if sudo systemctl enable "$service" >/dev/null 2>&1; then
            print_done "Enabled system service: $service"
        else
            print_warn "Failed to enable system service: $service"
        fi
    done

    local user_services=(
        "pipewire"
        "pipewire-pulse"
        "wireplumber"
        "hypridle"
    )

    for service in "${user_services[@]}"; do
        if systemctl --user --quiet is-enabled "$service" 2>/dev/null; then
            print_done "User service already enabled: $service"
        elif systemctl --user enable "$service" >/dev/null 2>&1; then
            print_done "Enabled user service: $service"
        else
            print_warn "User service $service not enabled (likely socket-activated, which is fine)"
        fi
    done
    print_done "System services configured"
}

setup_logind() {
    print_header "Lid Switch Behavior (suspend on close)"

    if ! confirm "Configure systemd-logind to suspend on lid close?"; then
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
HandleLidSwitchDocked=suspend
LidSwitchIgnoreInhibited=yes
HoldoffTimeoutSec=0s
InhibitDelayMaxSec=5
EOF
    print_done "Wrote $conf_file"

    print_warn "Lid switch changes will apply after reboot"
    print_warn "Skipping systemd-logind restart to avoid blanking the current session"
}

setup_firewall() {
    print_header "Firewall Setup (ufw)"

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
    print_header "Cloudflare WARP (opt-in)"

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
    print_header "Validating Installation"

    local all_ok=true

    if command -v niri &>/dev/null; then
        if niri validate 2>/dev/null; then
            print_done "Niri config is valid"
        else
            print_warn "Niri config validation failed -- check ~/.config/niri/config.kdl"
            all_ok=false
        fi
    else
        print_warn "niri not found in PATH (may need a reboot)"
        all_ok=false
    fi

    local critical_files=(
        "$HOME/.config/niri/config.kdl"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/waybar/style.css"
        "$HOME/.config/waybar/colors/monochrome.css"
        "$HOME/.config/waybar/scripts/brightness-control.sh"
        "$HOME/.config/waybar/scripts/caffeine-control.sh"
        "$HOME/.config/waybar/scripts/fullscreen-toggle.sh"
        "$HOME/.config/waybar/scripts/lock-screen.sh"
        "$HOME/.config/waybar/scripts/mic-control.sh"
        "$HOME/.config/waybar/scripts/monitor-refresh.sh"
        "$HOME/.config/waybar/scripts/open-drives.sh"
        "$HOME/.config/waybar/scripts/power-profile.sh"
        "$HOME/.config/waybar/scripts/prepare-sleep.sh"
        "$HOME/.config/waybar/scripts/suspend-now.sh"
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
            all_ok=false
        fi

        font_match=$(fc-match -f '%{family}\n' 'Material Design Icons' 2>/dev/null | head -n 1 || true)
        if [[ "$font_match" == *"Material Design Icons"* ]]; then
            print_done "Font: Material Design Icons"
        else
            print_warn "Material Design Icons font not resolving -- install ttf-material-design-icons-webfont"
            all_ok=false
        fi
    else
        print_warn "fontconfig not found -- cannot validate Waybar fonts"
        all_ok=false
    fi

    if $all_ok; then
        echo ""
        echo -e "${GREEN}${BOLD}  All files in place!${NC}"
        return 0
    fi

    return 1
}

cleanup_old_configs() {
    print_header "Clean Up Old Configs (Optional)"

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
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}Installation Complete!${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Your Niri setup is ready.${NC}"
    echo ""
    echo -e "  ${CYAN}Next steps:${NC}"
    echo -e "    1. Reboot your system"
    echo -e "    2. Select ${BOLD}niri-session${NC} from the ly login screen"
    echo -e "    3. Powerlevel10k is pre-configured (run ${BOLD}p10k configure${NC} to customize)"
    echo -e "    4. Press ${BOLD}Super+A${NC} for app launcher"
    echo -e "    5. Press ${BOLD}Super+T${NC} for terminal"
    echo ""
    echo -e "  ${CYAN}Key files:${NC}"
    echo -e "    Niri config  -> ~/.config/niri/config.kdl"
    echo -e "    Waybar       -> ~/.config/waybar/"
    echo -e "    Zsh config   -> ~/.zshrc"
    echo -e "    Keybindings  -> $SCRIPT_DIR/keybindings.md"
    echo ""
}

main() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╦ ╦╦ ╦╔═╗╔═╗  ╔╗╔╦╦═╗╦"
    echo "  ╠═╣╚╦╝╠═╝║╣   ║║║║╠╦╝║"
    echo "  ╩ ╩ ╩ ╩  ╚═╝  ╝╚╝╩╩╚═╩"
    echo -e "${NC}"
    echo -e "  ${BOLD}Arch Linux + Niri Wayland Setup${NC}"
    echo -e "  ${BLUE}Monochrome Theme${NC}"
    echo ""

    if ! confirm "Start installation?"; then
        echo -e "\n  ${YELLOW}Installation cancelled.${NC}\n"
        exit 0
    fi

    run_phase "Preflight checks" preflight
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
    else
        print_error "Validation failed; installation did not complete cleanly"
        exit 1
    fi
}

main "$@"
