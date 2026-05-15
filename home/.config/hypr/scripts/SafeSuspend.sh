#!/usr/bin/env bash
set -euo pipefail

quarantine_file="${HOME}/.local/state/gpu-watchdog/quarantine.env"
session_state_file="${HOME}/.local/state/session-startup-guard/state.env"
log_dir="${HOME}/__home_organized/logs"
log_file="${log_dir}/safe-suspend.log"
force_mode="${1:-}"

mkdir -p "${log_dir}"

if [[ "${force_mode}" == "--force" || "${ALLOW_UNSAFE_SUSPEND:-0}" == "1" ]]; then
  printf '[%s] action=suspend mode=forced\n' "$(date '+%F %T %Z')" >> "${log_file}"
  exec systemctl suspend
fi

reasons=()

if [[ -f "${quarantine_file}" ]]; then
  # shellcheck disable=SC1090
  source "${quarantine_file}"
  if [[ "${GPU_QUARANTINE:-0}" == "1" ]]; then
    reasons+=("gpu quarantine active${GPU_QUARANTINE_REASON:+: ${GPU_QUARANTINE_REASON}}")
  fi
fi

if [[ -f "${session_state_file}" ]]; then
  # shellcheck disable=SC1090
  source "${session_state_file}"
  if [[ "${SAFE_MODE:-0}" == "1" ]]; then
    reasons+=("session safe mode active${SAFE_REASON:+: ${SAFE_REASON}}")
  fi
fi

if (( ${#reasons[@]} > 0 )); then
  reason_text="$(IFS='; '; echo "${reasons[*]}")"
  printf '[%s] action=blocked fallback=lock-dpms reason=%s\n' "$(date '+%F %T %Z')" "${reason_text}" >> "${log_file}"
  notify-send "Suspend blocked" "${reason_text}" -u normal >/dev/null 2>&1 || true
  loginctl lock-session >/dev/null 2>&1 || true
  sleep 1
  hyprctl dispatch dpms off >/dev/null 2>&1 || true
  exit 0
fi

printf '[%s] action=suspend mode=normal\n' "$(date '+%F %T %Z')" >> "${log_file}"
exec systemctl suspend
