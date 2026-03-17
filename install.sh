#!/bin/bash

# ╔═══════════════════════════════════════════════════════╗
# ║          Hype Niri - Automated Installer              ║
# ║     Arch Linux + Niri Wayland Compositor Setup        ║
# ╚═══════════════════════════════════════════════════════╝

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────

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

confirm() {
    echo ""
    read -rp "  $(echo -e "${YELLOW}?${NC}") $1 [Y/n] " response
    case "$response" in
        [nN][oO]|[nN]) return 1 ;;
        *) return 0 ;;
    esac
}

# ─────────────────────────────────────────────────────────
# Preflight Checks
# ─────────────────────────────────────────────────────────

preflight() {
    print_header "Preflight Checks"

    if ! command -v pacman &>/dev/null; then
        print_error "This script requires Arch Linux (pacman not found)"
        exit 1
    fi
    print_done "Arch Linux detected"

    if ! command -v yay &>/dev/null; then
        print_warn "yay (AUR helper) not found"
        if confirm "Install yay?"; then
            print_step "Installing yay..."
            sudo pacman -S --needed --noconfirm git base-devel
            tmpdir=$(mktemp -d)
            git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
            (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$tmpdir"
            print_done "yay installed"
        else
            print_error "yay is required. Exiting."
            exit 1
        fi
    else
        print_done "yay found"
    fi

    if ! curl --connect-timeout 5 -fsS https://archlinux.org > /dev/null 2>&1; then
        print_error "No internet connection"
        exit 1
    fi
    print_done "Internet connection OK"
}

# ─────────────────────────────────────────────────────────
# Install Packages
# ─────────────────────────────────────────────────────────

install_packages() {
    print_header "Installing Packages"

    if [ ! -f "$SCRIPT_DIR/pkglist.txt" ]; then
        print_error "pkglist.txt not found at $SCRIPT_DIR/pkglist.txt"
        exit 1
    fi

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

    print_step "Starting installation (live output):"
    install_log="$(mktemp)"
    if ! stdbuf -oL -eL yay -S --needed --noconfirm "${packages[@]}" 2>&1 | tee "$install_log"; then
        print_error "Package installation failed. Last 40 log lines:"
        tail -n 40 "$install_log" | sed 's/^/    /'
        print_warn "Full install log kept at: $install_log"
        exit 1
    fi

    rm -f "$install_log"
    print_done "All packages installed"
}

# ─────────────────────────────────────────────────────────
# Backup Existing Configs
# ─────────────────────────────────────────────────────────

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

    has_existing=false
    for config in "${configs_to_backup[@]}"; do
        if [ -d "$HOME/.config/$config" ]; then
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
            print_done "Backup saved to $BACKUP_DIR"
        fi
    else
        print_done "No existing configs to back up"
    fi
}

# ─────────────────────────────────────────────────────────
# Copy Configurations
# ─────────────────────────────────────────────────────────

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

    chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null
    print_done "Made waybar scripts executable"

    mkdir -p "$HOME/Pictures/Wallpapers"
    if [ -d "$SCRIPT_DIR/Wallpapers" ] && [ "$(ls -A "$SCRIPT_DIR/Wallpapers" 2>/dev/null)" ]; then
        cp -r "$SCRIPT_DIR/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
        print_done "Copied wallpapers -> ~/Pictures/Wallpapers"
    fi
}

# ─────────────────────────────────────────────────────────
# Shell Setup (Zsh + Powerlevel10k)
# ─────────────────────────────────────────────────────────

setup_shell() {
    print_header "Setting Up Zsh"

    print_step "Installing fzf-tab plugin..."
    if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
        mkdir -p "$HOME/.zsh"
        git clone https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
        print_done "fzf-tab installed"
    else
        print_done "fzf-tab already installed"
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
            chsh -s /bin/zsh
            print_done "Default shell changed to zsh"
            print_warn "Log out and back in for this to take effect"
        fi
    else
        print_done "Zsh is already the default shell"
    fi
}

# ─────────────────────────────────────────────────────────
# GTK Theme Setup
# ─────────────────────────────────────────────────────────

setup_gtk() {
    print_header "GTK Theme Setup"

    # Write GTK 3 settings
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

    # Write GTK 4 settings
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

    # Write dconf settings directly for GNOME apps (Nautilus, etc.)
    # gsettings requires a running dbus session; dconf write works from any context.
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

# ─────────────────────────────────────────────────────────
# Desktop Integration Setup
# ─────────────────────────────────────────────────────────

setup_desktop_integrations() {
    print_header "Desktop Integration Setup"

    if command -v xdg-user-dirs-update &>/dev/null; then
        xdg-user-dirs-update
        print_done "XDG user directories initialized"
    else
        print_warn "xdg-user-dirs-update not found"
    fi
}

# ─────────────────────────────────────────────────────────
# System Configuration (requires root)
# ─────────────────────────────────────────────────────────

setup_system() {
    print_header "System Configuration (requires sudo)"

    # Pacman output styling
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

    # Ly display manager
    if confirm "Set up ly as display manager?"; then
        # Disable other display managers
        for dm in sddm gdm lightdm greetd; do
            if systemctl is-enabled "$dm" &>/dev/null; then
                sudo systemctl disable "$dm"
                print_step "Disabled $dm"
            fi
        done

        sudo systemctl enable ly
        print_done "Enabled ly display manager"
    fi

    # Polkit Rules
    print_step "Installing Polkit rules (NetworkManager)..."
    if [ -d "$SCRIPT_DIR/polkit" ] && [ "$(ls -A "$SCRIPT_DIR/polkit" 2>/dev/null)" ]; then
        sudo cp -r "$SCRIPT_DIR/polkit/"*.rules /etc/polkit-1/rules.d/ 2>/dev/null || true
        print_done "Polkit rules applied"
    fi

    # Enable essential services
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

    # User services (pipewire stack)
    local user_services=(
        "pipewire"
        "pipewire-pulse"
        "wireplumber"
    )

    for service in "${user_services[@]}"; do
        if sudo systemctl --global enable "$service" >/dev/null 2>&1; then
            print_done "Enabled user service: $service"
        else
            print_warn "User service $service not found (may use socket activation)"
        fi
    done
    print_done "System services configured"
}

# ─────────────────────────────────────────────────────────
# Post-Install Validation
# ─────────────────────────────────────────────────────────

validate() {
    print_header "Validating Installation"

    # Check niri config
    if command -v niri &>/dev/null; then
        if niri validate 2>/dev/null; then
            print_done "Niri config is valid"
        else
            print_warn "Niri config validation failed -- check ~/.config/niri/config.kdl"
        fi
    else
        print_warn "niri not found in PATH (may need a reboot)"
    fi

    # Check critical files
    local critical_files=(
        "$HOME/.config/niri/config.kdl"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/waybar/style.css"
        "$HOME/.config/alacritty/alacritty.toml"
        "$HOME/.config/fuzzel/fuzzel.ini"
        "$HOME/.config/mako/config"
        "$HOME/.config/fastfetch/config.jsonc"
        "$HOME/.config/hypr/hyprlock.conf"
        "$HOME/.config/hypr/hypridle.conf"
        "$HOME/.config/wlogout/layout"
        "$HOME/.config/gtk-3.0/settings.ini"
        "$HOME/.config/gtk-4.0/settings.ini"
        "$HOME/.zshrc"
    )

    all_ok=true
    for f in "${critical_files[@]}"; do
        if [ -f "$f" ]; then
            print_done "$(basename "$f")"
        else
            print_error "Missing: $f"
            all_ok=false
        fi
    done

    if $all_ok; then
        echo ""
        echo -e "${GREEN}${BOLD}  All files in place!${NC}"
    fi
}

# ─────────────────────────────────────────────────────────
# Cleanup Old Configs
# ─────────────────────────────────────────────────────────

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
        "$HOME/.config/qt5ct"
        "$HOME/.config/qt6ct"
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
}

# ─────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────

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

    preflight
    install_packages
    backup_configs
    copy_configs
    setup_shell
    setup_gtk
    setup_desktop_integrations
    setup_system
    cleanup_old_configs
    validate
    print_summary
}

main "$@"
