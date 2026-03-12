#!/usr/bin/env bash
set -euo pipefail

owner_home="${CODEX_OWNER_HOME:-/home/goringich}"
user_wrapper="${owner_home}/.local/bin/codex"

if [[ ! -x "$user_wrapper" ]]; then
  echo "Codex wrapper not found at $user_wrapper" >&2
  exit 1
fi

export HOME="$owner_home"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$owner_home/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$owner_home/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$owner_home/.local/state}"
export CODEX_OWNER_HOME="$owner_home"

if [[ "$(id -u)" -eq 0 ]]; then
  exec "$user_wrapper" "$@"
fi

exec sudo -E "$user_wrapper" "$@"
