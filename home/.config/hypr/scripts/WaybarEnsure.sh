#!/usr/bin/env bash
# Keep Waybar lifecycle predictable: one launcher, one restart path.

set -euo pipefail

CONFIG="${HOME}/.config/waybar/config"
STYLE="${HOME}/.config/waybar/style.css"
LOG_OUT="/tmp/waybar-session.out"
LOG_ERR="/tmp/waybar-session.err"
SESSION_ENV="${HOME}/.config/hypr/session.env"
DIAG_DISABLE_FILE="${HOME}/.local/state/session-startup-guard/disable-waybar"
MODE="${1:-ensure}"
SYSTEMD_UNIT="waybar.service"
WAYBAR_BIN="${WAYBAR_BIN:-$(command -v waybar || printf '/usr/bin/waybar')}"

load_session_env() {
  [[ -f "${SESSION_ENV}" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "${SESSION_ENV}"
  set +a
}

systemd_unit_loaded() {
  command -v systemctl >/dev/null 2>&1 || return 1
  [[ "$(systemctl --user show -p LoadState --value "${SYSTEMD_UNIT}" 2>/dev/null)" == "loaded" ]]
}

diagnostic_shell_disabled() {
  [[ -f "${DIAG_DISABLE_FILE}" ]]
}

run_waybar() {
  diagnostic_shell_disabled && exit 0
  load_session_env
  export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
  exec "${WAYBAR_BIN}" -c "${CONFIG}" -s "${STYLE}"
}

start_waybar() {
  diagnostic_shell_disabled && exit 0
  if systemd_unit_loaded; then
    systemctl --user start "${SYSTEMD_UNIT}"
  else
    nohup "${BASH:-/bin/bash}" "$0" run >"${LOG_OUT}" 2>"${LOG_ERR}" </dev/null &
  fi
}

is_running() {
  if systemd_unit_loaded && systemctl --user --quiet is-active "${SYSTEMD_UNIT}"; then
    return 0
  fi
  pgrep -x waybar >/dev/null 2>&1
}

case "${MODE}" in
  run)
    run_waybar
    ;;
  ensure)
    diagnostic_shell_disabled && exit 0
    if is_running; then
      exit 0
    fi
    start_waybar
    ;;
  restart)
    diagnostic_shell_disabled && exit 0
    if systemd_unit_loaded; then
      systemctl --user restart "${SYSTEMD_UNIT}"
    else
      pkill -x waybar >/dev/null 2>&1 || true
      sleep 0.2
      start_waybar
    fi
    ;;
  reload)
    diagnostic_shell_disabled && exit 0
    if systemd_unit_loaded; then
      systemctl --user reload-or-restart "${SYSTEMD_UNIT}"
    else
      if is_running; then
        pkill -SIGUSR2 -x waybar >/dev/null 2>&1 || true
        sleep 0.3
      fi
      if ! is_running; then
        start_waybar
      fi
    fi
    ;;
  *)
    printf 'Usage: %s [ensure|restart|reload]\n' "$0" >&2
    exit 2
    ;;
esac
