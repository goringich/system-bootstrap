# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

# Avoid .zcompdump rename races in non-TTY interactive shells such as `zsh -lic`.
# Keep the normal shared completion cache for real terminal sessions.
if [[ -o interactive && ! -t 1 ]]; then
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    mkdir -p "$XDG_CACHE_HOME/zsh"
    export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump-${HOST%%.*}-${${ZSH_VERSION}//./_}-$$"
fi

ZSH_THEME="blinks"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

if [[ -o interactive && ! -t 1 ]]; then
    source "$ZSH/oh-my-zsh.sh" 2>/dev/null
else
    source "$ZSH/oh-my-zsh.sh"
fi




# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display Pokemon-colorscripts``
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
# The wide mixed logo layout uses cursor positioning, so we only enable it when
# the terminal is wide enough. Narrower windows fall back to plain fastfetch
# without a logo to prevent wraps and shifted text on startup.
render_terminal_splash() {
    command -v fastfetch >/dev/null 2>&1 || return 0

    local columns="${COLUMNS:-0}"
    if [[ ! "$columns" =~ ^[0-9]+$ ]] || (( columns <= 0 )); then
        if command -v tput >/dev/null 2>&1; then
            columns="$(tput cols 2>/dev/null || printf '0')"
        else
            columns=0
        fi
    fi

    if (( columns >= 120 )) && command -v pokemon-colorscripts >/dev/null 2>&1; then
        pokemon-colorscripts --no-title -s -r | fastfetch \
            -c "$HOME/.config/fastfetch/config-pokemon.jsonc" \
            --logo-type file-raw \
            --logo-height 10 \
            --logo-width 5 \
            --logo -
        return
    fi

    if (( columns >= 92 )); then
        fastfetch --pipe true -c "$HOME/.config/fastfetch/config-pokemon.jsonc" --logo none
        return
    fi

    fastfetch \
        --pipe true \
        --logo none \
        --separator " -> " \
        --structure Title:OS:Kernel:WM:Shell:Terminal:CPU:GPU:Memory:Display:Uptime
}

if [[ -o interactive && -t 1 ]]; then
    render_terminal_splash
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
HISTSIZE=500000
SAVEHIST=500000
setopt appendhistory
setopt inc_append_history
setopt share_history
setopt extended_history
setopt hist_fcntl_lock
unsetopt hist_ignore_dups
unsetopt hist_ignore_space
unsetopt hist_expire_dups_first
unsetopt hist_verify

export ZSH_HISTORY_BACKUP_DIR="$HOME/__home_organized/artifacts/zsh-history"

backup_zsh_history_snapshot() {
    [[ -f "$HISTFILE" ]] || return 0

    mkdir -p "$ZSH_HISTORY_BACKUP_DIR" || return 1

    local latest_snapshot="$ZSH_HISTORY_BACKUP_DIR/latest.zsh_history"
    local daily_snapshot="$ZSH_HISTORY_BACKUP_DIR/$(date +%Y-%m-%d).zsh_history"

    if [[ ! -f "$latest_snapshot" ]] || ! cmp -s "$HISTFILE" "$latest_snapshot"; then
        command cp "$HISTFILE" "$latest_snapshot"
        command cp "$HISTFILE" "$daily_snapshot"
    fi
}

autoload -Uz add-zsh-hook

sync_zsh_history() {
    builtin fc -AI "$HISTFILE" 2>/dev/null || true
    builtin fc -R "$HISTFILE" 2>/dev/null || true
}

history_prompt_maintenance() {
    sync_zsh_history
    backup_zsh_history_snapshot
}

if [[ -o interactive && -t 1 ]]; then
    mkdir -p "$HOME/.ssh/controlmasters"
    chmod 700 "$HOME/.ssh/controlmasters" 2>/dev/null || true
    sync_zsh_history
    backup_zsh_history_snapshot
    add-zsh-hook precmd history_prompt_maintenance
    add-zsh-hook zshexit backup_zsh_history_snapshot
fi
alias telegram-desktop="QT_QPA_PLATFORM=xcb /usr/bin/telegram-desktop"
export PATH="$HOME/.local/bin:$PATH"

if [[ -f "$HOME/.config/codex/mcp-secrets.env" ]]; then
    source "$HOME/.config/codex/mcp-secrets.env"
fi

if [[ -f "$HOME/.openclaw/secrets/gateway.env" ]]; then
    set -a
    source "$HOME/.openclaw/secrets/gateway.env"
    set +a
fi

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

_df_local_hide_mounts_raw() {
    local home_source base_source

    home_source="$(findmnt -J -T "$HOME" -o TARGET,SOURCE 2>/dev/null | jq -r '.filesystems[0].source // empty')" || return 0
    [[ -n "$home_source" ]] || return 0
    base_source="${home_source%%\[*}"

    findmnt -J -o TARGET,SOURCE 2>/dev/null |
    jq -r '
        def walk_fs:
            . as $node
            | [$node]
            + (($node.children // []) | map(walk_fs) | add);
        .filesystems
        | map(walk_fs)
        | add
        | .[]
        | [.target, .source]
        | @tsv
    ' |
    while IFS=$'\t' read -r target source; do
        [[ -n "$target" && -n "$source" ]] || continue
        [[ "$target" == "$HOME" ]] && continue
        [[ "$target" == "$HOME/"* ]] || continue
        [[ "${source#"$base_source"}" != "$source" ]] || continue
        print -r -- "$target"
    done |
    sort -u
}

_df_local_hide_mounts() {
    _df_local_hide_mounts_raw |
    while IFS= read -r target; do
        print -r -- "${target// /\\040}"
    done
}

_df_pretty() {
    local hide_json

    hide_json="$(_df_local_hide_mounts_raw | jq -R . | jq -s .)"
    duf -json 2>/dev/null |
    jq -r --argjson hide "${hide_json:-[]}" '
        map(select(.mount_point as $mp | ($hide | index($mp) | not))) |
        .[] |
        [
          .device_type,
          .mount_point,
          .total,
          .used,
          .free,
          (if .total > 0 then ((.used / .total * 1000 | floor) / 10) else 0 end | tostring) + "%",
          (if (.type // "") == "" then .fs_type else .type end),
          .device
        ] | @tsv
    ' |
    awk -F '\t' '
        function human(x,   i, n, units) {
            split("B KiB MiB GiB TiB PiB EiB", units, " ")
            n = x + 0
            for (i = 1; n >= 1024 && i < 7; i++) n /= 1024
            if (i == 1) return sprintf("%d%s", n, units[i])
            return sprintf("%.1f%s", n, units[i])
        }
        function repeat(s, n,   out, i) {
            out = ""
            for (i = 0; i < n; i++) out = out s
            return out
        }
        function pad(str, width,   s) {
            s = str
            gsub(/\033\[[0-9;]*m/, "", s)
            return str repeat(" ", width - length(s))
        }
        function border(left, fill, mid, right) {
            return left repeat(fill, w1 + 2) mid repeat(fill, w2 + 2) mid repeat(fill, w3 + 2) mid repeat(fill, w4 + 2) mid repeat(fill, w5 + 2) mid repeat(fill, w6 + 2) mid repeat(fill, w7 + 2) right
        }
        function print_header(title) {
            count = section_count[title] + 0
            printf "╭%s╮\n", repeat("─", total_width - 2)
            printf "│ %-*s │\n", total_width - 4, count " " title
            print border("├", "─", "┬", "┤")
            printf "│ %s │ %s │ %s │ %s │ %s │ %s │ %s │\n", pad("MOUNTED ON", w1), pad("SIZE", w2), pad("USED", w3), pad("AVAIL", w4), pad("USE%", w5), pad("TYPE", w6), pad("FILESYSTEM", w7)
            print border("├", "─", "┼", "┤")
        }
        function print_row(idx) {
            printf "│ %s │ %s │ %s │ %s │ %s │ %s │ %s │\n", pad(mp[idx], w1), pad(size[idx], w2), pad(used[idx], w3), pad(avail[idx], w4), pad(usep[idx], w5), pad(typev[idx], w6), pad(fs[idx], w7)
        }
        BEGIN {
            w1 = length("MOUNTED ON")
            w2 = length("SIZE")
            w3 = length("USED")
            w4 = length("AVAIL")
            w5 = length("USE%")
            w6 = length("TYPE")
            w7 = length("FILESYSTEM")
        }
        function section_name(kind) {
            return (kind == "local" ? "local devices" : kind " devices")
        }
        {
            kind = $1
            section = section_name(kind)
            idx = ++n
            kind_order[kind] = 1
            group[idx] = section
            group_kind[idx] = kind
            section_count[section]++
            mp[idx] = $2
            size[idx] = human($3)
            used[idx] = human($4)
            avail[idx] = human($5)
            usep[idx] = $6
            typev[idx] = $7
            fs[idx] = $8

            if (length(mp[idx]) > w1) w1 = length(mp[idx])
            if (length(size[idx]) > w2) w2 = length(size[idx])
            if (length(used[idx]) > w3) w3 = length(used[idx])
            if (length(avail[idx]) > w4) w4 = length(avail[idx])
            if (length(usep[idx]) > w5) w5 = length(usep[idx])
            if (length(typev[idx]) > w6) w6 = length(typev[idx])
            if (length(fs[idx]) > w7) w7 = length(fs[idx])
        }
        END {
            total_width = w1 + w2 + w3 + w4 + w5 + w6 + w7 + 22
            split("local", preferred, " ")
            printed_any = 0
            for (p = 1; p <= length(preferred); p++) {
                kind = preferred[p]
                section = section_name(kind)
                if (!(kind in kind_order)) continue
                if (printed_any) print ""
                print_header(section)
                for (i = 1; i <= n; i++) {
                    if (group_kind[i] != kind) continue
                    print_row(i)
                }
                print border("╰", "─", "┴", "╯")
                printed_any = 1
            }
        }
    '
}

df() {
    local hide_file

    if (( $# == 0 )); then
        _df_pretty
        return
    fi

    hide_file="$(mktemp)" || return 1
    _df_local_hide_mounts > "$hide_file"
    command df -P "$@" | awk 'NR==FNR { hide[$1]=1; next } NR==1 || !($NF in hide)' "$hide_file" -
    rm -f "$hide_file"
}

dfh() {
    if (( $# == 0 )); then
        _df_pretty
    else
        df "$@"
    fi
}

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
    render_terminal_splash
}

# List git repositories by locating every .git entry under the given roots.
gitrepos() {
    local roots=("$@")
    local gitpath

    if (( ${#roots[@]} == 0 )); then
        roots=(/)
    fi

    command find "${roots[@]}" \
        \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
        -name .git -print 2>/dev/null |
    while IFS= read -r gitpath; do
        dirname "$gitpath"
    done |
    sort -u
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

realcode-project() {
    if (( $# > 0 )); then
        realcode "$@"
    else
        realcode "$PWD"
    fi
}

# >>> codex hacker prompt >>>
export PATH="$HOME/.local/bin:$PATH"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export CLICOLOR=1
export LSCOLORS="Gxfxcxdxbxegedabagacad"
export LS_COLORS="di=1;92:ln=1;36:so=1;35:pi=33:ex=1;93:bd=1;94:cd=1;94:su=30;41:sg=30;46:tw=30;42:ow=30;43"

autoload -Uz colors vcs_info
colors
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats '%F{39}[git:%b]%f'
zstyle ':vcs_info:git:*' actionformats '%F{39}[git:%b|%a]%f'

precmd() {
  vcs_info
}

typeset -gA CUSTOM_COMMAND_DESCRIPTIONS
typeset -gA CUSTOM_COMMAND_CATEGORIES
typeset -gA CUSTOM_COMMAND_USAGES

autoload -Uz run-help 2>/dev/null || true

register_custom_command() {
  CUSTOM_COMMAND_CATEGORIES[$1]="$2"
  CUSTOM_COMMAND_DESCRIPTIONS[$1]="$3"
}

register_custom_usage() {
  CUSTOM_COMMAND_USAGES[$1]="$2"
}

register_custom_command ls nav 'lsd with icons'
register_custom_command l nav 'long ls view'
register_custom_command la nav 'show hidden files'
register_custom_command lla nav 'long view with hidden files'
register_custom_command lt nav 'directory tree view'
register_custom_command cdi nav 'interactive zoxide jump'
register_custom_command .. nav 'go up one directory'
register_custom_command ... nav 'go up two directories'
register_custom_command .... nav 'go up three directories'
register_custom_command cd nav 'cd routed through zoxide when target is provided'
register_custom_command mkcd nav 'create directory and enter it'
register_custom_command fcd nav 'fzf directory picker'
register_custom_command fopen nav 'fzf file picker for editor'
register_custom_command fm nav 'open available file manager'
register_custom_command v nav 'open editor'

register_custom_command g git 'git shortcut'
register_custom_command gs git 'git status short branch view'
register_custom_command ga git 'git add'
register_custom_command gc git 'git commit'
register_custom_command gca git 'git commit --amend'
register_custom_command gp git 'git push'
register_custom_command gl git 'git pull'
register_custom_command glg git 'compact git graph log'
register_custom_command gg git 'open lazygit'
register_custom_command gu git 'open gitui'
register_custom_command lg git 'open tig'
register_custom_command gitrepos git 'list directories that have initialized git repositories'
register_custom_command realcode git 'count real code lines with product-focused defaults, or only Markdown via --md-only'
register_custom_command realcode-project git 'run realcode for current directory or provided path with product-focused defaults'

register_custom_command t system 'open tmux'
register_custom_command ta system 'attach to tmux session'
register_custom_command tn system 'create tmux session'
register_custom_command c system 'clear terminal'
register_custom_command h system 'show shell history'
register_custom_command path system 'print PATH line by line'
register_custom_command mkdir system 'mkdir with parents and verbose output'
register_custom_command grep system 'ripgrep shortcut'
register_custom_command df system 'filesystem usage via duf with bind mounts hidden by default'
register_custom_command dfh system 'human-readable filesystem usage with bind mounts hidden by default'
register_custom_command duh system 'directory sizes one level deep'
register_custom_command psg system 'search running processes'
register_custom_command ports system 'list listening ports'
register_custom_command myip system 'show local IP addresses'
register_custom_command pingg system 'ping google.com'
register_custom_command extract system 'extract archive by extension'
register_custom_command fkill system 'fzf process picker and kill -9'
register_custom_command sysinfo-pro system 'render adaptive terminal splash'
register_custom_command telegram-desktop system 'launch Telegram with XCB backend'
register_custom_command help meta 'show custom commands help'

register_custom_usage gitrepos $'Usage: gitrepos [search-root ...]\nExamples:\n  gitrepos\n  gitrepos /home/goringich\n  gitrepos ~ /etc /opt\nNotes:\n  Defaults to / when no roots are provided.\n  Skips /proc, /sys, /dev, and /run.\n  Includes nested and cached repos if they contain .git.'
register_custom_usage realcode $'Usage: realcode [path] [--with-tests] [--with-docs] [--with-config] [--all] [--md-only]\nExamples:\n  realcode\n  realcode .\n  realcode ~/project --with-tests\n  realcode ~/project --md-only\nCounts only non-empty code lines in supported source/config files.\nDefaults to product mode: skips tests, docs, samples, vendored tools, CI and build/config noise.\nUse --md-only to count only Markdown files.\nUse --with-tests, --with-config or --all for broader counts.'
register_custom_usage realcode-project $'Usage: realcode-project [path]\nShortcut for running realcode on the current directory or a provided path.\nUses the same product-focused defaults as realcode; pass extra flags to widen the count.'
register_custom_usage df $'Usage: df [duf-options]\nShows filesystem usage through duf with bind mounts hidden by default.\nUse `duf -all` or `command df` when you need the raw unfiltered mount view.'
register_custom_usage dfh $'Usage: dfh [duf-options]\nHuman-readable filesystem usage with bind mounts hidden by default.\nFalls back to `command df -hT` when duf is unavailable.'

custom_help_category_label() {
  case "$1" in
    nav) print 'Navigation & Files' ;;
    git) print 'Git & Project' ;;
    system) print 'System & Terminal' ;;
    meta) print 'Meta' ;;
    *) print "$1" ;;
  esac
}

print_custom_commands_table() {
  local category="$1"
  local label="$2"
  local cmd desc
  local -a commands
  local -i max_cmd=7
  local -i max_desc=11
  local border header

  for cmd in ${(on)${(k)CUSTOM_COMMAND_DESCRIPTIONS}}; do
    [[ ${CUSTOM_COMMAND_CATEGORIES[$cmd]} == "$category" ]] || continue
    commands+=("$cmd")
    desc=${CUSTOM_COMMAND_DESCRIPTIONS[$cmd]}
    (( ${#cmd} > max_cmd )) && max_cmd=${#cmd}
    (( ${#desc} > max_desc )) && max_desc=${#desc}
  done

  (( ${#commands[@]} )) || return

  border="+-${(r:$max_cmd::--:)}-+-${(r:$max_desc::--:)}-+"
  header=$(printf '| %-'"$max_cmd"'s | %-'"$max_desc"'s |' 'Command' 'Description')

  print ''
  print -P "%F{81}${label}%f"
  print -- "$border"
  print -- "$header"
  print -- "$border"

  for cmd in $commands; do
    desc=${CUSTOM_COMMAND_DESCRIPTIONS[$cmd]}
    printf '| %-'"$max_cmd"'s | %-'"$max_desc"'s |\n' "$cmd" "$desc"
  done

  print -- "$border"
}

print_custom_commands_help() {
  print ''
  print -P '%F{117}Custom shell commands%f  Use %F{190}help <command>%f for details.'
  print_custom_commands_table nav "$(custom_help_category_label nav)"
  print_custom_commands_table git "$(custom_help_category_label git)"
  print_custom_commands_table system "$(custom_help_category_label system)"
  print_custom_commands_table meta "$(custom_help_category_label meta)"
}

print_custom_command_details() {
  local cmd="$1"
  local category desc usage

  if [[ -z ${CUSTOM_COMMAND_DESCRIPTIONS[$cmd]:-} ]]; then
    return 1
  fi

  category=$(custom_help_category_label "${CUSTOM_COMMAND_CATEGORIES[$cmd]}")
  desc=${CUSTOM_COMMAND_DESCRIPTIONS[$cmd]}
  usage=${CUSTOM_COMMAND_USAGES[$cmd]:-}

  print ''
  print -P "%F{81}${cmd}%f"
  print -P "  %F{244}Category:%f ${category}"
  print -P "  %F{244}Description:%f ${desc}"
  if [[ -n "$usage" ]]; then
    print -P "  %F{244}Details:%f"
    print -- "$usage" | sed 's/^/    /'
  fi
}

help() {
  if [[ $# -eq 0 ]]; then
    print_custom_commands_help
    return 0
  fi

  if print_custom_command_details "$1"; then
    return 0
  fi

  if whence run-help >/dev/null 2>&1; then
    run-help "$@"
  else
    whence -v "$1"
  fi
}

PROMPT='%F{39}%n%f %F{201}@%m%f %F{46}%~%f ${vcs_info_msg_0_}%(?.%F{82}.%F{196})%#%f '
# <<< codex hacker prompt <<<
source "/home/goringich/Desktop/Obsidian/System/zsh/load-custom-commands.zsh"
