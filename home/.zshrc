# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="blinks"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh




# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display Pokemon-colorscripts``
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
#pokemon-colorscripts --no-title -s -r #without fastfetch
if [[ -o interactive && -t 1 ]]; then
    pokemon-colorscripts --no-title -s -r | fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
fi

# fastfetch. Will be disabled if above colorscript was chosen to install
#fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
if [[ -o interactive && -t 1 ]]; then
    source <(fzf --zsh)
fi

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
unsetopt inc_append_history share_history extended_history
alias telegram-desktop="QT_QPA_PLATFORM=xcb /usr/bin/telegram-desktop"
export PATH="$HOME/.local/bin:$PATH"

# === SSH Agent Configuration ===
ssh_agent_ready() {
    if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
        return 1
    fi
    ssh-add -l >/dev/null 2>&1
    case $? in
        0|1) return 0 ;; # 0=has keys, 1=no keys, both mean agent is reachable
        *) return 1 ;;
    esac
}

if [[ -o interactive && -t 1 ]]; then
    systemd_sock="/run/user/$(id -u)/ssh-agent.socket"
    fallback_sock="$HOME/.ssh/agent/agent.sock"

    if [ -S "$systemd_sock" ]; then
        export SSH_AUTH_SOCK="$systemd_sock"
    fi

    if ! ssh_agent_ready; then
        mkdir -p "$HOME/.ssh/agent"
        chmod 700 "$HOME/.ssh/agent"
        rm -f "$fallback_sock"
        if eval "$(ssh-agent -s -a "$fallback_sock")" >/dev/null 2>&1; then
            export SSH_AUTH_SOCK="$fallback_sock"
        fi
    fi

    if ssh_agent_ready; then
        ssh-add -l >/dev/null 2>&1
        if [ $? -eq 1 ]; then
            for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/github"; do
                [ -f "$key" ] && ssh-add "$key" >/dev/null 2>&1
            done
        fi
    fi
fi

# === Zoxide Configuration ===
# Keep regular cd, use z/zi as jump helpers
alias cdi='zi'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'


source /home/goringich/.config/broot/launcher/bash/br
# autosuggestions (показывает серым подсказки по истории)
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# syntax highlighting (подсвечивает команды как в IDE)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH="$HOME/.local/bin:$PATH"

eval "$(zoxide init zsh --cmd z)"

# ESP-IDF environment (auto-load if installed locally)
if [[ -o interactive && -t 1 && -f "$HOME/esp/esp-idf/export.sh" ]]; then
    export IDF_PATH="$HOME/esp/esp-idf"
    source "$IDF_PATH/export.sh" >/dev/null 2>&1 || true
fi

# === Terminal Pro Pack (keeps current setup, adds convenience) ===
setopt auto_cd interactive_comments auto_pushd pushd_ignore_dups pushd_silent

export EDITOR="${EDITOR:-nano}"
export VISUAL="${VISUAL:-$EDITOR}"

if command -v bat >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --height=70% --layout=reverse --border --preview='bat --style=numbers --color=always --line-range=:300 {} 2>/dev/null'"
fi

alias c='clear'
alias h='history 1'
alias path='echo -e ${PATH//:/\\n}'
alias mkdir='mkdir -pv'
alias grep='rg'
alias dfh='df -hT'
alias duh='du -h -d 1'
alias psg='ps aux | rg -i'
alias ports='ss -tulpn'
alias myip='ip -brief address'
alias pingg='ping google.com'
alias t='tmux'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend'
alias gp='git push'
alias gl='git pull'
alias glg='git log --graph --decorate --oneline --all'
alias v='$EDITOR'

# Default command remaps to advanced tools (interactive convenience)
if command -v lsd >/dev/null 2>&1; then alias ls='lsd'; fi
if command -v bat >/dev/null 2>&1; then alias cat='bat --paging=never --style=plain'; fi
if command -v rg >/dev/null 2>&1; then alias grep='rg'; fi
if command -v fd >/dev/null 2>&1; then alias find='fd'; fi
if command -v dust >/dev/null 2>&1; then alias du='dust'; fi
if command -v duf >/dev/null 2>&1; then alias df='duf'; fi
if command -v procs >/dev/null 2>&1; then alias ps='procs'; fi
if command -v btop >/dev/null 2>&1; then alias top='btop'; fi
if command -v prettyping >/dev/null 2>&1; then alias ping='prettyping'; fi
if command -v dog >/dev/null 2>&1; then alias dig='dog'; fi
if command -v dool >/dev/null 2>&1; then alias dstat='dool'; fi
if command -v nvim >/dev/null 2>&1; then alias vi='nvim'; alias vim='nvim'; fi
if command -v xh >/dev/null 2>&1; then alias http='xh'; fi
if command -v tldr >/dev/null 2>&1; then alias cheat='tldr'; fi
if command -v watchexec >/dev/null 2>&1; then alias watchman='watchexec'; fi

alias fm='yazi || lf || ranger || nnn'
alias gg='lazygit'
alias gu='gitui'
alias lg='tig'

# Default cd behavior: use zoxide ranking when target is provided
cd() {
    if [[ $# -eq 0 ]]; then
        builtin cd
    elif command -v z >/dev/null 2>&1; then
        z "$@"
    else
        builtin cd "$@"
    fi
}

mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

extract() {
    if [[ -z "${1:-}" || ! -f "$1" ]]; then
        echo "Usage: extract <archive-file>"
        return 1
    fi
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz) tar xzf "$1" ;;
        *.tar.xz|*.txz) tar xJf "$1" ;;
        *.tar.zst|*.tzst) tar --zstd -xf "$1" ;;
        *.tar) tar xf "$1" ;;
        *.zip) unzip "$1" ;;
        *.7z) 7z x "$1" ;;
        *.rar) unrar x "$1" ;;
        *.gz) gunzip "$1" ;;
        *.bz2) bunzip2 "$1" ;;
        *.xz) unxz "$1" ;;
        *) echo "extract: unsupported archive format: $1"; return 1 ;;
    esac
}

fcd() {
    local dir
    dir="$(fd --type d --hidden --follow --exclude .git . "${1:-.}" 2>/dev/null | fzf +m)" || return
    cd -- "$dir" || return
}

fopen() {
    local file
    file="$(fd --type f --hidden --follow --exclude .git . "${1:-.}" 2>/dev/null | fzf --preview 'bat --style=numbers --color=always --line-range=:300 {} 2>/dev/null')" || return
    "$EDITOR" "$file"
}

fkill() {
    local pid
    pid="$(ps -ef | sed 1d | fzf -m | awk '{print $2}')" || return
    [[ -n "$pid" ]] && kill -9 $pid
}

sysinfo-pro() {
    fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc"
}

if [[ -o interactive && -t 1 ]]; then
    bindkey '^P' up-history
    bindkey '^N' down-history
fi

if [[ -o interactive && -t 1 ]]; then
    setopt complete_in_word auto_menu
    zstyle ':completion:*' menu select
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

    fzf-insert-path-widget() {
        local selected
        selected="$(fd --hidden --follow --exclude .git . "${1:-.}" 2>/dev/null | fzf --height=70% --layout=reverse)" || return
        LBUFFER+="${(q)selected}"
    }
    zle -N fzf-insert-path-widget
    bindkey '^F' fzf-insert-path-widget

    fzf-edit-file-widget() {
        local selected
        selected="$(fd --type f --hidden --follow --exclude .git . "${1:-.}" 2>/dev/null | fzf --preview 'bat --style=numbers --color=always --line-range=:200 {} 2>/dev/null')" || return
        LBUFFER+="$EDITOR ${(q)selected}"
        zle accept-line
    }
    zle -N fzf-edit-file-widget
    bindkey '^O' fzf-edit-file-widget
fi
