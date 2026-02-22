# Hype Niri

> A clean, professional, highly functional Wayland setup based on the Niri scrollable-tiling compositor and the Everforest dark scheme.

![Niri](https://img.shields.io/badge/Niri-Wayland-7fbbb3?style=for-the-badge&logo=wayland&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-a7c080?style=for-the-badge&logo=archlinux&logoColor=white)
![Everforest Theme](https://img.shields.io/badge/Theme-Everforest-2d353b?style=for-the-badge)

<br/>

## Overview

Personal dotfiles for a minimal Arch Linux setup using the **Niri** scrollable tiling Wayland compositor. Focused on delivering a premium, smooth, and full-featured desktop experience using native Wayland tools—no X11 dependencies.

## Tech Stack

| Component | Tool / Link |
| :--- | :--- |
| **Compositor** | [Niri](https://github.com/YaLTeR/niri) |
| **Bar** | [Waybar](https://github.com/Alexays/Waybar) |
| **Terminal** | [Alacritty](https://github.com/alacritty/alacritty) |
| **Shell** | [Zsh](https://www.zsh.org/) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| **Launcher** | [Fuzzel](https://codeberg.org/dnkl/fuzzel) |
| **Notifications** | [Mako](https://github.com/emersion/mako) |
| **Lock Screen** | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| **Idle Daemon** | [Hypridle](https://github.com/hyprwm/hypridle) |
| **Wallpaper** | [Swww](https://github.com/LGFae/swww) |
| **Login Manager** | [Greetd](https://sr.ht/~kennylevinsen/greetd/) + [TuiGreet](https://github.com/apognu/tuigreet) |
| **Fetch App** | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) |
| **Logout Menu** | [Wlogout](https://github.com/ArtsyMacaw/wlogout) |

<br/>

## Installation

For a fully automated installation, clone the repository and run the setup script:

```bash
git clone https://github.com/Dijo-404/Hype_Niri.git
cd Hype_Niri
./install.sh
```

> [!NOTE]  
> See [INSTALL.md](INSTALL.md) for manual setup instructions and post-installation steps.

<br/>

## Repository Structure

```text
.
├── alacritty/       # Fast, GPU-accelerated terminal configuration
├── fastfetch/       # System information fetch utility with custom logo
├── fuzzel/          # Application launcher styled for Everforest
├── greetd/          # TUI-based minimal login manager
├── hypr/            # Hypridle configuration for lock/sleep management
├── hyprlock/        # Lock screen configuration
├── mako/            # Notification daemon configuration
├── niri/            # Core Niri compositor settings and rules
├── Wallpapers/      # Default curated wallpapers
├── waybar/          # Comprehensive status bar + utility scripts
├── wlogout/         # Power menu configuration
├── zsh/             # Shell config (.zshrc) and aliases
├── install.sh       # Automated installation script
├── pkglist.txt      # Master list of required packages
└── *.md             # Documentation files
```

<br/>

## Documentation

- **[Keybindings Reference](keybindings.md)** - Learn how to navigate and manage windows
- **[Zsh Aliases](alias.md)** - Shell aliases
- **[Installation Guide](INSTALL.md)** - Detailed setup instructions