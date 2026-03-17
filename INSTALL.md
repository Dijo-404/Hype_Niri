# Hype Niri -- Installation Guide

## Quick Install (Recommended)

The automated install script handles everything: installing packages, copying configurations, setting up your shell environment, applying the dark theme, and enabling necessary system services.

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
grep -v '^#' pkglist.txt | grep -v '^$' | xargs yay -S --needed --noconfirm
```

### 2. Copy Configurations

Move the dotfiles to their respective locations in your home directory.

```bash
mkdir -p ~/.config

# Copy Wayland/UI configurations
cp -r niri waybar alacritty fuzzel mako fastfetch wlogout hypr ~/.config/

# Copy Shell configuration
cp zsh/.zshrc ~/
cp zsh/.p10k.zsh ~/

# Make scripts executable
chmod +x ~/.config/waybar/scripts/*.sh
```

### 3. Apply Dark Theme

Set the dark theme for GTK apps (Nautilus, etc.):

```bash
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-application-prefer-dark-theme=true
EOF

cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

# Apply via dconf (ensures Nautilus and other GNOME apps use dark theme)
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
dconf write /org/gnome/desktop/interface/icon-theme "'Papirus-Dark'"
```

### 4. System-Wide Setup

These steps require elevated privileges (`sudo`).

```bash
# Enable Ly display manager
sudo systemctl enable ly

# Enable system services
sudo systemctl enable NetworkManager bluetooth

# Change default shell to Zsh
chsh -s /usr/bin/zsh

# Setup wallpapers
mkdir -p ~/Pictures/Wallpapers
cp -r Wallpapers/* ~/Pictures/Wallpapers/

# Install fzf-tab zsh plugin
git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab

# Copy polkit rules
sudo cp polkit/*.rules /etc/polkit-1/rules.d/
```

### 5. Reboot Your System

Reboot to initialize all changes and the new login manager:

```bash
reboot
```

> [!NOTE]
> At the Ly login screen, select **niri-session** before logging in.

---

## Updating

To pull the latest changes from the repository and apply them:

```bash
cd Hype_Niri
git pull
./install.sh
```

The install script backs up existing configs before overwriting and only installs new packages (uses `--needed`).

To update only system packages without re-running the script:

```bash
yay -Syu
```

---

## Post-Install Steps

- **Powerlevel10k Prompt**: The theme is pre-configured out of the box. Run `p10k configure` in your terminal to customize it.
- **Learn the Controls**: Check out `keybindings.md` to learn how to navigate the Niri compositor.
- **Wallpapers**: The Waybar script automatically looks for wallpapers inside `~/Pictures/Wallpapers/`.

## Documentation Links

- [Keybindings Reference](keybindings.md)
- [Zsh Aliases](alias.md)
