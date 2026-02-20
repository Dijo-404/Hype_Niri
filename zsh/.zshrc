# Disable P10k instant prompt — we print a greeting + fastfetch on startup
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# Exit if non-interactive
[[ $- != *i* ]] && return

# ── Aliases ──────────────────────────────────────

# General
alias c='clear'
alias cl='clear'

# ls (overridden by eza below if available)
alias ls='ls --color=auto'
alias l='ls -lh'
alias la='ls -lAh'
alias ll='ls -lh'
alias lsa='ls -lah'
alias lt='ls -lhtr'
alias lS='ls -lhS'
alias ld='ls -lhd */'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# Grep
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Safety nets
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias ln='ln -iv'
alias mkdir='mkdir -pv'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gb='git branch'

# System
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias ports='netstat -tulanp'

# Package management (yay)
alias syu='yay -Syu'
alias install='yay -S'
alias remove='yay -Rns'
alias search='yay -Ss'
alias pkginfo='yay -Qi'

# Editor
alias v='nvim'
alias vim='nvim'
alias nv='nvim'
alias e='nvim'

# Tools
alias lg='lazygit'
alias ld='lazydocker'
alias h='history'
alias j='jobs -l'
alias path='echo "$PATH" | tr ":" "\n"'

# Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias drm='docker rm'
alias drmi='docker rmi'

# Config shortcuts
alias zshrc='nvim ~/.zshrc'
alias niriconf='nvim ~/.config/niri/config.kdl'
alias alacrittyconf='nvim ~/.config/alacritty/alacritty.toml'

# Misc
alias wget='wget -c'
alias ff='fastfetch'
alias reload='source ~/.zshrc'

# ── Tool Integrations ────────────────────────────

# fzf
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh
fi
if [[ -f /usr/share/fzf/completion.zsh ]]; then
    source /usr/share/fzf/completion.zsh
fi
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --inline-info"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# zoxide (smarter cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# eza (modern ls)
if command -v eza &> /dev/null; then
    alias ls='eza --color=auto --icons'
    alias l='eza -lh --icons'
    alias la='eza -lah --icons'
    alias ll='eza -lh --icons'
    alias lsa='eza -lah --icons'
    alias lt='eza -lh --icons --sort=modified'
    alias lS='eza -lh --icons --sort=size'
    alias tree='eza --tree --icons'
fi

# bat (better cat)
if command -v bat &> /dev/null; then
    alias cat='bat --style=auto'
    alias catp='bat --style=plain'
    export BAT_THEME="Monokai Extended"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ── Conda ────────────────────────────────────────

# >>> conda initialize >>>
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# ── Zsh Options ──────────────────────────────────

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt APPEND_HISTORY
setopt SHARE_HISTORY

# Tab completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Colors
autoload -Uz colors && colors

# ── Prompt ───────────────────────────────────────

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme




fastfetch

# ── Plugins (must be last) ───────────────────────

[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# p10k config (run `p10k configure` to customize)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
