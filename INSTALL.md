# Hype Niri -- Installation Guide

## Quick Install (Recommended)

The automated install script handles everything: installing packages, copying configurations, setting up your shell environment, applying the dark theme, enabling necessary system services, and optionally configuring a firewall and Cloudflare WARP.

```bash
git clone https://github.com/Dijo-404/Hype_Niri.git
cd Hype_Niri
chmod +x install.sh
./install.sh
```

The installer is interactive at every irreversible step — backup, display manager switch, lid-switch behavior, firewall, WARP, and shell change all confirm before acting.

> [!TIP]
> The Powerlevel10k prompt theme is pre-configured. Run `p10k configure` if you want to customize it.

> [!NOTE]
> The installer uses `pacman` for official repository packages and `yay` only for AUR packages.

---

## Manual Install

If you prefer to understand what is happening under the hood or selectively apply configurations, follow these manual steps. The order matters — clean up stale configs before writing new ones.

### 1. Install Required Packages

The repository contains a `pkglist.txt` file listing all necessary dependencies.

```bash
mapfile -t official < <(awk '!/^#/ && NF {print $1}' pkglist.txt | while read -r p; do pacman -Si "$p" >/dev/null 2>&1 && printf '%s\n' "$p"; done)
mapfile -t aur < <(awk '!/^#/ && NF {print $1}' pkglist.txt | while read -r p; do pacman -Si "$p" >/dev/null 2>&1 || printf '%s\n' "$p"; done)

[ "${#official[@]}" -eq 0 ] || sudo pacman -S --needed --noconfirm "${official[@]}"
[ "${#aur[@]}" -eq 0 ] || yay -S --needed --noconfirm "${aur[@]}"
```

### 2. Back Up and Clean Up Existing Configs

If you already have configs in `~/.config`, back them up before overwriting:

```bash
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
for c in niri waybar alacritty fuzzel mako fastfetch wlogout hypr; do
    [ -d "$HOME/.config/$c" ] && cp -r "$HOME/.config/$c" "$BACKUP_DIR/"
done
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
[ -f "$HOME/.p10k.zsh" ] && cp "$HOME/.p10k.zsh" "$BACKUP_DIR/.p10k.zsh"
```

Remove any stale configs from previous setups that will conflict (`qt5ct` / `qt6ct` are written fresh in step 4 — do **not** delete them):

```bash
rm -rf ~/.config/Kvantum ~/.config/rofi ~/.config/dunst
[ -f ~/.config/hypr/hyprland.conf ] && rm ~/.config/hypr/hyprland.conf
```

### 3. Copy Configurations

Move the dotfiles to their respective locations in your home directory.

```bash
mkdir -p ~/.config ~/.cache/cliphist ~/Pictures/Screenshots ~/Pictures/Wallpapers

cp -r niri waybar alacritty fuzzel mako fastfetch wlogout hypr ~/.config/

[ -d Wallpapers ] && cp -r Wallpapers/* ~/Pictures/Wallpapers/

cp zsh/.zshrc ~/
cp zsh/.p10k.zsh ~/

chmod +x ~/.config/waybar/scripts/*.sh
```

### 4. Apply Dark Theme (GTK + Qt + dconf)

Set the dark theme for GTK and Qt apps. Apply via `dconf` so GNOME apps (Nautilus, etc.) pick it up immediately.

```bash
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.config/qt5ct ~/.config/qt6ct

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

cat > ~/.config/qt5ct/conf << 'EOF'
[General]
icon_theme=Papirus-Dark
standard_dialogs=default
EOF
cp ~/.config/qt5ct/conf ~/.config/qt6ct/conf

dconf write /org/gnome/desktop/interface/color-scheme   "'prefer-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme      "'Adwaita-dark'"
dconf write /org/gnome/desktop/interface/icon-theme     "'Papirus-Dark'"
dconf write /org/gnome/desktop/interface/cursor-theme   "'Adwaita'"
dconf write /org/gnome/desktop/interface/cursor-size    "24"
dconf write /org/gnome/desktop/interface/font-name      "'JetBrainsMono Nerd Font 10'"

papirus-folders -C black --theme Papirus-Dark
```

### 5. System-Wide Setup

These steps require elevated privileges (`sudo`).

```bash
sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 6/' /etc/pacman.conf

sudo cp polkit/*.rules /etc/polkit-1/rules.d/

for dm in sddm gdm lightdm greetd; do
    systemctl is-enabled "$dm" &>/dev/null && sudo systemctl disable "$dm"
done
sudo systemctl enable ly

sudo systemctl enable NetworkManager bluetooth

systemctl --user enable pipewire pipewire-pulse wireplumber hypridle 2>/dev/null || true

sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-hype-niri-lid.conf >/dev/null << 'EOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=suspend
LidSwitchIgnoreInhibited=yes
HoldoffTimeoutSec=0s
InhibitDelayMaxSec=5
EOF
```

### 6. Shell Setup

```bash
git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab

chsh -s /usr/bin/zsh
```

### 7. Optional: Privacy Networking

Both ufw and Cloudflare WARP are **opt-in** — skip this section if you don't want them.

#### Firewall (ufw)

Standard desktop defaults: deny incoming, allow outgoing, allow loopback.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default allow routed
sudo ufw allow in on lo
sudo ufw allow out on lo
sudo ufw logging low
sudo ufw --force enable
sudo systemctl enable ufw.service
```

Verify:
```bash
sudo ufw status verbose
```

Disable later with `sudo ufw disable`. The installer never opens SSH or any other port — if you need SSH, add `sudo ufw allow ssh` yourself.

#### Cloudflare WARP

The `cloudflare-warp-bin` AUR package ships a system service (`warp-svc`) and a user CLI (`warp-cli`). DoH (DNS-over-HTTPS) is the safe default; full WARP is a VPN tunnel.

```bash
sudo systemctl enable --now warp-svc

warp-cli --accept-tos registration new

warp-cli --accept-tos mode doh

warp-cli --accept-tos connect
warp-cli --accept-tos status
```

Disconnect anytime with `warp-cli disconnect`. Inspect logs with `journalctl -u warp-svc`.

### 8. Reboot Your System

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

The install script requires a backup before overwriting existing configs and only installs new packages (uses `--needed`).

To update packages without re-running the script:

```bash
sudo pacman -Syu
yay -Syu --aur
```

---

## Post-Install Steps

- **Powerlevel10k Prompt**: The theme is pre-configured out of the box. Run `p10k configure` in your terminal to customize it.
- **Learn the Controls**: Check out `keybindings.md` to learn how to navigate the Niri compositor.
- **Wallpapers**: The Waybar script automatically looks for wallpapers inside `~/Pictures/Wallpapers/`. Use `Super+Shift+W` to select one; the selected wallpaper is saved in `~/.local/state/hypr/current_wallpaper` and restored after lock, sleep, reboot, and shutdown.
- **Lock Screen**: `Super+L` locks via hyprlock and uses the saved wallpaper pointer from `~/.local/state/hypr/current_wallpaper`.
- **Firewall / WARP**: If you skipped step 7 and want them later, just run the relevant commands above — both are idempotent.

## Troubleshooting

### Can't access a Windows partition from Linux (dual-boot)

If your Windows partition doesn't appear in Nautilus, or appears but won't open / mounts read-only:

**1. Install the prerequisites** (already in `pkglist.txt`):

```bash
yay -S --needed ntfs-3g gvfs udisks2
```

- `ntfs-3g` — NTFS driver. Even though the kernel has `ntfs3` built-in, ntfs-3g handles Fast Startup detection cleanly.
- `gvfs` — lets Nautilus mount partitions on click.
- `udisks2` — the mount daemon Nautilus talks to.

**2. Disable Windows Fast Startup** (this is the cause ~90% of the time).

Fast Startup leaves the Windows NTFS partition hibernated on shutdown, and Linux refuses to mount it writable to protect the filesystem. In Windows:

`Control Panel → Power Options → "Choose what the power buttons do" → "Change settings that are currently unavailable"` → **uncheck "Turn on fast startup"** → Save. Then shut Windows down fully (Shift+Restart → Power off) and boot back into Linux.

**3. Mount it.**

Open Nautilus, click "Other Locations", and click the Windows partition — it should mount and open. Or from the terminal:

```bash
lsblk -f

sudo mkdir -p /mnt/windows
sudo mount -t ntfs3 /dev/nvme0n1pX /mnt/windows
```

If `mount` reports `falling back to read-only`, Fast Startup is still on or Windows was not shut down cleanly — boot back into Windows, fully shut down, retry.

### Want it auto-mounted on every boot?

Add it to `/etc/fstab`. Get the UUID first:

```bash
sudo blkid /dev/nvme0n1pX
```

Then append to `/etc/fstab`:

```
UUID=XXXXXXXX-XXXX  /mnt/windows  ntfs3  defaults,nofail,uid=1000,gid=1000,umask=022  0  0
```

`nofail` is critical — it keeps the system bootable if the Windows partition ever vanishes or is unmountable.

---

## Documentation Links

- [Keybindings Reference](keybindings.md)
- [Zsh Aliases](alias.md)
