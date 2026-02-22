#!/bin/bash

# ╔═══════════════════════════════════════════════════════╗
# ║          Hype Niri - Automated Installer              ║
# ║     Arch Linux + Niri Wayland Compositor Setup        ║
# ╚═══════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
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
    echo -e "  ${GREEN}→${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_done() {
    echo -e "  ${GREEN}✓${NC} $1"
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

    # Check if running on Arch
    if ! command -v pacman &>/dev/null; then
        print_error "This script requires Arch Linux (pacman not found)"
        exit 1
    fi
    print_done "Arch Linux detected"

    # Check for yay
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

    # Check internet
    if ! ping -c 1 archlinux.org &>/dev/null; then
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

    # Read package list, strip versions
    mapfile -t packages < <(
        grep -v '^#' "$SCRIPT_DIR/pkglist.txt" | \
        grep -v '^$' | \
        awk '{print $1}'
    )

    total=${#packages[@]}
    print_step "Installing $total packages..."
    echo ""

    # Install all at once for efficiency
    yay -S --needed --noconfirm "${packages[@]}" 2>&1 | while read -r line; do
        # Show only important lines
        if [[ "$line" == *"installing"* ]] || [[ "$line" == *"warning"* ]]; then
            echo "    $line"
        fi
    done

    print_done "All packages installed"
}

# ─────────────────────────────────────────────────────────
# Backup Existing Configs
# ─────────────────────────────────────────────────────────

backup_configs() {
    print_header "Backing Up Existing Configs"

    BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

    configs_to_backup=(
        "niri"
        "waybar"
        "alacritty"
        "fuzzel"
        "mako"
        "fastfetch"
        "hyprlock"
        "wlogout"
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
            # Backup shell configs
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

    # Core configs
    local configs=(
        "niri"
        "waybar"
        "alacritty"
        "fuzzel"
        "mako"
        "fastfetch"
        "hyprlock"
        "wlogout"
    )

    for config in "${configs[@]}"; do
        if [ -d "$SCRIPT_DIR/$config" ]; then
            rm -rf "$HOME/.config/$config"
            cp -r "$SCRIPT_DIR/$config" "$HOME/.config/$config"
            print_done "Copied $config → ~/.config/$config"
        fi
    done

    # Ensure scripts are executable
    chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null
    print_done "Made waybar scripts executable"

    # Wallpapers
    mkdir -p "$HOME/Pictures/Wallpapers"
    if [ -d "$SCRIPT_DIR/Wallpapers" ]; then
        cp -r "$SCRIPT_DIR/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null
        print_done "Copied wallpapers → ~/Pictures/Wallpapers"
    fi
}

# ─────────────────────────────────────────────────────────
# Shell Setup (Zsh + Powerlevel10k)
# ─────────────────────────────────────────────────────────

setup_shell() {
    print_header "Setting Up Zsh"

    # Copy .zshrc
    if [ -f "$SCRIPT_DIR/zsh/.zshrc" ]; then
        cp "$SCRIPT_DIR/zsh/.zshrc" "$HOME/.zshrc"
        print_done "Copied .zshrc → ~/.zshrc"
    fi

    # Change default shell to zsh
    current_shell=$(basename "$SHELL")
    if [ "$current_shell" != "zsh" ]; then
        if confirm "Change default shell to zsh?"; then
            chsh -s /bin/zsh
            print_done "Default shell changed to zsh"
            print_warn "You'll need to log out and back in for this to take effect"
        fi
    else
        print_done "Zsh is already the default shell"
    fi
}

# ─────────────────────────────────────────────────────────
# System Configuration (requires root)
# ─────────────────────────────────────────────────────────

setup_system() {
    print_header "System Configuration (requires sudo)"

    # Greetd
    if confirm "Set up greetd as login manager?"; then
        if [ -f "$SCRIPT_DIR/greetd/config.toml" ]; then
            sudo mkdir -p /etc/greetd
            sudo cp "$SCRIPT_DIR/greetd/config.toml" /etc/greetd/config.toml
            print_done "Copied greetd config"

            # Disable other display managers
            for dm in sddm gdm lightdm; do
                if systemctl is-enabled "$dm" &>/dev/null; then
                    sudo systemctl disable "$dm"
                    print_step "Disabled $dm"
                fi
            done

            sudo systemctl enable greetd
            print_done "Enabled greetd service"
        fi
    fi

    # Polkit Rules
    print_step "Installing Polkit rules (NetworkManager)..."
    if [ -d "$SCRIPT_DIR/polkit" ]; then
        sudo cp -r "$SCRIPT_DIR/polkit/"*.rules /etc/polkit-1/rules.d/ 2>/dev/null || true
        print_done "Polkit rules applied"
    fi

    # Enable essential services
    print_step "Enabling system services..."

    local services=(
        "NetworkManager"
        "bluetooth"
        "pipewire"
        "pipewire-pulse"
        "wireplumber"
    )

    for service in "${services[@]}"; do
        if systemctl list-unit-files "$service.service" &>/dev/null; then
            sudo systemctl enable "$service" 2>/dev/null || true
            print_step "Enabled system service: $service"
        elif systemctl --global list-unit-files "$service.service" &>/dev/null; then
            systemctl --user enable "$service" 2>/dev/null || systemctl --global enable "$service" 2>/dev/null || true
            print_step "Enabled user service: $service"
        else
            print_warn "Service $service not found"
        fi
    done
    print_done "System services configured"
}

# ─────────────────────────────────────────────────────────
# GTK Theme Setup
# ─────────────────────────────────────────────────────────

setup_gtk() {
    print_header "GTK Theme Setup"

    # Set GTK theme via gsettings if available
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 10" 2>/dev/null || true
        print_done "GTK settings applied via gsettings"
    fi

    # Create GTK settings.ini
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-application-prefer-dark-theme=true
EOF
    print_done "Created GTK 3 settings"

    mkdir -p "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-application-prefer-dark-theme=true
EOF
    print_done "Created GTK 4 settings"
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
            print_warn "Niri config validation failed — check ~/.config/niri/config.kdl"
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
        "$HOME/.config/hyprlock/hyprlock.conf"
        "$HOME/.config/wlogout/layout"
        "$HOME/.zshrc"
    )

    all_ok=true
    for f in "${critical_files[@]}"; do
        if [ -f "$f" ]; then
            print_done "$(basename "$f") ✓"
        else
            print_error "Missing: $f"
            all_ok=false
        fi
    done

    if $all_ok; then
        echo ""
        echo -e "${GREEN}${BOLD}  ✓ All files in place!${NC}"
    fi
}

# ─────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────

cleanup_hyprland() {
    print_header "Clean Up Old Hyprland Configs (Optional)"

    if [ -d "$HOME/.config/hypr" ]; then
        print_warn "Found existing Hyprland config at ~/.config/hypr"
        if confirm "Remove old Hyprland config?"; then
            rm -rf "$HOME/.config/hypr"
            print_done "Removed ~/.config/hypr"
        fi
    fi

    # Remove old X11/Qt configs
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
    echo -e "    1. Log out or reboot"
    echo -e "    2. Select ${BOLD}Niri${NC} from the greetd login"
    echo -e "    3. Run ${BOLD}p10k configure${NC} on first zsh launch"
    echo -e "    4. Press ${BOLD}Super+A${NC} for app launcher"
    echo -e "    5. Press ${BOLD}Super+T${NC} for terminal"
    echo ""
    echo -e "  ${CYAN}Key files:${NC}"
    echo -e "    Niri config  → ~/.config/niri/config.kdl"
    echo -e "    Waybar       → ~/.config/waybar/"
    echo -e "    Zsh config   → ~/.zshrc"
    echo -e "    Keybindings  → $SCRIPT_DIR/keybindings.md"
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
    echo -e "  ${BLUE}Everforest Dark Theme${NC}"
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
    setup_system
    cleanup_hyprland
    validate
    print_summary
}

main "$@"
