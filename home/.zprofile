export PATH="$HOME/.local/bin:$PATH"

if [[ -f "$HOME/.config/codex/mcp-secrets.env" ]]; then
    source "$HOME/.config/codex/mcp-secrets.env"
fi

if [[ -f "$HOME/.openclaw/secrets/gateway.env" ]]; then
    set -a
    source "$HOME/.openclaw/secrets/gateway.env"
    set +a
fi

#if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
#       Hyprland 
#fi

# >>> codex local bin path >>>
export PATH="$HOME/.local/bin:$PATH"
# <<< codex local bin path <<<
