#!/usr/bin/env bash

set -euo pipefail

telegram_bin="${TELEGRAM_BIN:-$HOME/.local/bin/Telegram}"
base_dir="${XDG_DATA_HOME:-$HOME/.local/share}/TelegramDesktop"
state_dir="$HOME/__home_organized/runtime/telegram-multi-window"
state_file="${state_dir}/next-slot"

has_telegram_window() {
  hyprctl clients 2>/dev/null | grep -qE 'class: (org\.telegram\.desktop|io\.github\.tdesktop_x64\.TDesktop|TelegramDesktop)'
}

has_telegram_process() {
  pgrep -x Telegram >/dev/null 2>&1
}

cleanup_stale_telegram() {
  pkill -TERM -x Telegram >/dev/null 2>&1 || true
  sleep 2
  pkill -KILL -x Telegram >/dev/null 2>&1 || true
}

launch_instance() {
  local workdir="$1"

  mkdir -p "${workdir}"
  "${telegram_bin}" -many -workdir "${workdir}" >/dev/null 2>&1 &
}

mkdir -p "${state_dir}"

next_slot=1
if [[ -f "${state_file}" ]]; then
  read -r saved_slot < "${state_file}" || true
  if [[ "${saved_slot:-}" =~ ^[123]$ ]]; then
    next_slot="${saved_slot}"
  fi
fi

# Recover from the "killed Telegram, no window comes back" state:
# if processes are still alive but Hyprland sees no Telegram window,
# clear the stale single-instance state and restart from slot 1.
if ! has_telegram_window; then
  if has_telegram_process; then
    cleanup_stale_telegram
  fi
  next_slot=1
fi

case "${next_slot}" in
  1)
    launch_instance "${base_dir}"
    following_slot=2
    ;;
  2)
    launch_instance "${base_dir}-2"
    following_slot=3
    ;;
  3)
    launch_instance "${base_dir}-3"
    following_slot=1
    ;;
esac

printf '%s\n' "${following_slot}" > "${state_file}"
