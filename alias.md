# Zsh Aliases

## General
- `c`, `cl`: Clear screen
- `ls`: Colorized `ls` (or `eza` if installed)
- `l`, `ll`: Long list
- `la`, `lsa`: List all including hidden
- `lt`: Sort by modification time
- `lS`: Sort by size
- `tree`: Tree view (via `eza`)
- `grep`: Colorized `grep`
- `..`, `...`, `....`: Go up directories

## Safety Nets
- `cp`: Interactive & verbose copy
- `mv`: Interactive & verbose move
- `rm`: Interactive remove
- `mkdir`: Create parent directories & verbose

## Git
- `g`: `git`
- `gs`: `git status`
- `ga`: `git add`
- `gaa`: `git add .`
- `gc`, `gcm`: `git commit`
- `gp`: `git push`
- `gpl`: `git pull`
- `gd`: `git diff`
- `gl`: `git log --oneline --graph`
- `gco`: `git checkout`
- `gb`: `git branch`

## Package Management (Yay)
- `syu`: Update all (`yay -Syu`)
- `install`: `yay -S`
- `remove`: `yay -Rns`
- `search`: `yay -Ss`
- `pkginfo`: `yay -Qi`

## Docker
- `d`: `docker`
- `dc`: `docker compose`
- `dps`: `docker ps`
- `dpsa`: `docker ps -a`
- `di`: `docker images`
- `dex`: `docker exec -it`

## Editors & Tools
- `v`, `vim`, `nv`, `e`: `nvim`
- `lg`: `lazygit`
- `ld`: `lazydocker`
- `cat`: `bat` (with syntax highlighting)

## Config Shortcuts
- `zshrc`: Edit `~/.zshrc`
- `niriconf`: Edit Niri config
- `alacrittyconf`: Edit Alacritty config
- `reload`: Source `~/.zshrc`

## System
- `df`: Human-readable disk usage
- `free`: Human-readable memory
- `ports`: Show open ports
- `ff`: Fastfetch
