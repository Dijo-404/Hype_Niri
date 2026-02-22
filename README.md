# Hype Niri

> Arch Linux + Niri — Everforest themed scrollable-tiling Wayland setup

![Niri](https://img.shields.io/badge/Niri-Wayland-7fbbb3?style=flat-square)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-a7c080?style=flat-square&logo=archlinux&logoColor=white)
![Everforest](https://img.shields.io/badge/Theme-Everforest-2d353b?style=flat-square)

## Overview

Personal dotfiles for a minimal Arch Linux setup using the **Niri** scrollable tiling Wayland compositor with the **Everforest** dark color scheme. Fully Wayland-native — no X11 dependencies.

## Stack

| Component | Tool |
|---|---|
| Compositor | [Niri](https://github.com/YaLTeR/niri) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) |
| Terminal | [Alacritty](https://github.com/alacritty/alacritty) |
| Shell | [Zsh](https://www.zsh.org/) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| Launcher | [Fuzzel](https://codeberg.org/dnkl/fuzzel) |
| Notifications | [Mako](https://github.com/emersion/mako) |
| Lock Screen | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| Idle Daemon | [Swayidle](https://github.com/swaywm/swayidle) |
| Wallpaper | [Swww](https://github.com/LGFae/swww) |
| Login | [Greetd](https://sr.ht/~kennylevinsen/greetd/) + [TuiGreet](https://github.com/apognu/tuigreet) |
| Fetch | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) |

## Install

```bash
git clone https://github.com/Dijo-404/Hype_Niri.git
cd Hype_Niri
./install.sh
```

See [INSTALL.md](INSTALL.md) for manual setup.

## Structure

```
├── alacritty/       # Terminal config
├── fastfetch/       # System fetch + custom logo
├── fuzzel/          # App launcher
├── greetd/          # Login manager
├── mako/            # Notifications
├── niri/            # Compositor config
├── Wallpapers/      # Default wallpapers
├── waybar/          # Bar config, styles, scripts
├── zsh/             # Shell config (.zshrc)
├── install.sh       # Automated installer
├── pkglist.txt      # Package list
└── keybindings.md   # Key reference
```

## Docs

- [Keybindings](keybindings.md)
- [Aliases](alias.md)
- [Install Guide](INSTALL.md)