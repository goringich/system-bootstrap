#!/usr/bin/env bash
set -euo pipefail

state_dir="${HOME}/.local/state/session-startup-guard"
waybar_flag="${state_dir}/disable-waybar"
swaync_flag="${state_dir}/disable-swaync"

mkdir -p "${state_dir}"

case "${1:-status}" in
  enable)
    : > "${waybar_flag}"
    : > "${swaync_flag}"
    printf 'diagnostic_mode=enabled\n'
    printf 'effect=waybar_and_swaync_disabled_on_next_session_start\n'
    ;;
  enable-waybar-only)
    rm -f "${waybar_flag}"
    : > "${swaync_flag}"
    printf 'diagnostic_mode=waybar_only_enabled\n'
    printf 'effect=swaync_disabled_waybar_allowed_on_next_session_start\n'
    ;;
  enable-swaync-only)
    : > "${waybar_flag}"
    rm -f "${swaync_flag}"
    printf 'diagnostic_mode=swaync_only_enabled\n'
    printf 'effect=waybar_disabled_swaync_allowed_on_next_session_start\n'
    ;;
  disable)
    rm -f "${waybar_flag}" "${swaync_flag}"
    printf 'diagnostic_mode=disabled\n'
    ;;
  status)
    printf 'waybar=%s\n' "$([[ -f "${waybar_flag}" ]] && echo disabled || echo enabled)"
    printf 'swaync=%s\n' "$([[ -f "${swaync_flag}" ]] && echo disabled || echo enabled)"
    ;;
  *)
    printf 'Usage: %s {enable|enable-waybar-only|enable-swaync-only|disable|status}\n' "$0" >&2
    exit 2
    ;;
esac
