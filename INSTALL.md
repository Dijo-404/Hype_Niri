# Hype Niri — Installation Guide

## Quick Install (Recommended)

The automated install script handles everything: installing packages, copying configurations, setting up your shell environment, and enabling necessary system services.

```bash
git clone https://github.com/Dijo-404/Hype_Niri.git
cd Hype_Niri
chmod +x install.sh
./install.sh
```

> [!TIP]  
> The Powerlevel10k prompt theme is pre-configured. Run `p10k configure` if you want to customize it.

---

## Manual Install

If you prefer to understand what is happening under the hood or selectively apply configurations, follow these manual steps.

### 1. Install Required Packages

The repository contains a `pkglist.txt` file listing all necessary dependencies.

> [!IMPORTANT]  
> This assumes you have an AUR helper installed, such as `yay`.

```bash
cat pkglist.txt | grep -v '^#' | grep -v '^$' | xargs yay -S --needed --noconfirm
```

### 2. Copy Configurations

Move the dotfiles to their respective locations in your home directory.

```bash
mkdir -p ~/.config

# Copy Wayland/UI configurations
cp -r niri waybar alacritty fuzzel mako fastfetch wlogout hypr ~/.config/

# Copy Shell configuration
cp zsh/.zshrc ~/
```

### 3. System-Wide Setup

These steps require elevated privileges (`sudo`).

```bash
# Set up Greetd (Login Manager)
sudo cp greetd/config.toml /etc/greetd/config.toml
sudo systemctl enable greetd

# Change Default Shell to Zsh
chsh -s /usr/bin/zsh

# Setup Wallpapers
mkdir -p ~/Pictures/Wallpapers
cp -r Wallpapers/* ~/Pictures/Wallpapers/

# Make scripts executable
chmod +x ~/.config/waybar/scripts/*.sh
```

### 4. Reboot Your System

Reboot to initialize all changes and the new login manager:

```bash
reboot
```

> [!NOTE]  
> At the `greetd` login screen, make sure to select the **Niri** session before logging in.

---

## Post-Install Steps

- **Powerlevel10k Prompt**: The theme is pre-configured out of the box. Run `p10k configure` in your terminal if you want to customize it.
- **Learn the Controls**: Check out `keybindings.md` to learn how to navigate the Niri compositor.
- **Wallpapers**: The Waybar script automatically looks for wallpapers inside `~/Pictures/Wallpapers/`.

## Documentation Links

- [Keybindings Reference](keybindings.md)
- [Zsh Aliases](alias.md)
