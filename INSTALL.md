# Hype Niri — Installation Guide

## Quick Install

```bash
git clone https://github.com/Dijo-404/Hype_Niri.git
cd Hype_Niri
chmod +x install.sh
./install.sh
```

The install script handles everything: packages, configs, shell setup, and system services.

## Manual Install

### 1. Install Packages

```bash
# Requires yay (AUR helper)
cat pkglist.txt | grep -v '^#' | grep -v '^$' | xargs yay -S --needed --noconfirm
```

### 2. Copy Configs

```bash
mkdir -p ~/.config

cp -r niri ~/.config/
cp -r waybar ~/.config/
cp -r alacritty ~/.config/
cp -r fuzzel ~/.config/
cp -r mako ~/.config/
cp -r fastfetch ~/.config/

cp zsh/.zshrc ~/
```

### 3. System Setup

```bash
# Login manager
sudo cp greetd/config.toml /etc/greetd/config.toml
sudo systemctl enable greetd

# Default shell
chsh -s /bin/zsh

# Wallpapers
cp -r Wallpapers/* ~/Pictures/Wallpapers/

# Make scripts executable
chmod +x ~/.config/waybar/scripts/*.sh
```

### 4. Reboot

Select **Niri** from the greetd login screen.

## Post-Install

- Run `p10k configure` on first zsh launch
- Check `keybindings.md` for key reference
- Wallpapers go in `~/Pictures/Wallpapers/`

## Documentation

- [Keybindings](keybindings.md)
- [Aliases](alias.md)
