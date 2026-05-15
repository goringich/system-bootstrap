#!/usr/bin/env bash
set -euo pipefail

state_dir="${HOME}/.local/state/session-startup-guard"
log_dir="${HOME}/__home_organized/logs"
state_file="${state_dir}/state.env"
log_file="${log_dir}/session-startup-guard.log"
diag_disable_swaync_file="${state_dir}/disable-swaync"
startup_disable_swaync_file="${state_dir}/disable-swaync-startup"
nonessential_user_timers_disable_file="${state_dir}/disable-nonessential-user-timers"
gpu_quarantine_file="${HOME}/.local/state/gpu-watchdog/quarantine.env"

mkdir -p "${state_dir}" "${log_dir}"

trim_file() {
  local file="$1"
  local max_lines="$2"
  [[ -f "${file}" ]] || return 0
  local lines
  lines="$(wc -l < "${file}")"
  if (( lines > max_lines )); then
    tail -n "${max_lines}" "${file}" > "${file}.tmp"
    mv "${file}.tmp" "${file}"
  fi
}

collect_current_boot_crashes() {
  journalctl -b 0 --no-pager 2>/dev/null \
    | rg -i 'NVRM: Xid|flip event timeout|lost display notification|error while waiting for gpu progress|Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)|xdg-desktop-portal-hyprland.service: Failed with result|libaquamarine' \
    | tail -n 20 || true
}

collect_previous_boot_crashes() {
  journalctl -b -1 --no-pager 2>/dev/null \
    | rg -i 'NVRM: Xid|flip event timeout|lost display notification|error while waiting for gpu progress|Process .*Hyprland.*(terminated abnormally|dumped core)|Process .*xdg-desktop-por.*(terminated abnormally|dumped core)|xdg-desktop-portal-hyprland.service: Failed with result|libaquamarine' \
    | tail -n 20 || true
}

collect_unclean_shutdown_markers() {
  journalctl -b 0 --no-pager 2>/dev/null \
    | rg -i 'corrupted or uncleanly shut down' \
    | tail -n 10 || true
}

collect_current_failed_units() {
  {
    systemctl --failed --no-pager --plain --no-legend 2>/dev/null
    systemctl --user --failed --no-pager --plain --no-legend 2>/dev/null
  } | sed '/^$/d' || true
}

load_state() {
  if [[ -f "${state_file}" ]]; then
    # shellcheck disable=SC1090
    source "${state_file}"
  fi
}

write_state() {
  cat > "${state_file}" <<EOF
SAFE_MODE='${SAFE_MODE}'
SAFE_REASON='${SAFE_REASON}'
SAFE_DETECTED_AT='${SAFE_DETECTED_AT}'
EOF
}

cmd="${1:-init}"
shift || true

case "${cmd}" in
  init)
    ts="$(date '+%F %T %Z')"
    unclean_markers="$(collect_unclean_shutdown_markers)"
    current_boot_crashes="$(collect_current_boot_crashes)"
    previous_boot_crashes="$(collect_previous_boot_crashes)"
    current_failed_units="$(collect_current_failed_units)"
    GPU_QUARANTINE=0
    GPU_QUARANTINE_REASON=""
    if [[ -f "${gpu_quarantine_file}" ]]; then
      # shellcheck disable=SC1090
      source "${gpu_quarantine_file}"
    fi

    SAFE_MODE=0
    SAFE_REASON="normal startup"
    SAFE_DETECTED_AT="${ts}"

    reasons=()
    if [[ -n "${unclean_markers}" ]]; then
      reasons+=("current boot detected dirty journal recovery")
    fi
    if [[ -n "${current_boot_crashes}" ]]; then
      reasons+=("current boot already has Hyprland/GPU crash signals")
    fi
    if [[ -n "${previous_boot_crashes}" ]]; then
      reasons+=("previous boot ended with Hyprland/GPU crash signals")
    fi
    if [[ -n "${current_failed_units}" ]]; then
      reasons+=("current boot already has failed units")
    fi
    if [[ "${GPU_QUARANTINE:-0}" == "1" ]]; then
      reasons+=("gpu quarantine is active${GPU_QUARANTINE_REASON:+: ${GPU_QUARANTINE_REASON}}")
    fi

    if (( ${#reasons[@]} > 0 )); then
      SAFE_MODE=1
      SAFE_REASON="$(IFS='; '; echo "${reasons[*]}")"
    fi

    : > "${startup_disable_swaync_file}"
    if (( SAFE_MODE == 1 )); then
      : > "${nonessential_user_timers_disable_file}"
    else
      rm -f "${nonessential_user_timers_disable_file}"
    fi
    write_state

    printf '[%s] safe_mode=%s reason=%s\n' "${ts}" "${SAFE_MODE}" "${SAFE_REASON}" >> "${log_file}"
    printf '[%s] swaync_startup_block=armed\n' "${ts}" >> "${log_file}"
    if [[ -n "${unclean_markers}" ]]; then
      printf '%s\n' "${unclean_markers}" | sed 's/^/[unclean] /' >> "${log_file}"
    fi
    if [[ -n "${current_boot_crashes}" ]]; then
      printf '%s\n' "${current_boot_crashes}" | sed 's/^/[current-boot] /' >> "${log_file}"
    fi
    if [[ -n "${previous_boot_crashes}" ]]; then
      printf '%s\n' "${previous_boot_crashes}" | sed 's/^/[previous-boot] /' >> "${log_file}"
    fi
    if [[ -n "${current_failed_units}" ]]; then
      printf '%s\n' "${current_failed_units}" | sed 's/^/[failed-unit] /' >> "${log_file}"
    fi
    if [[ "${GPU_QUARANTINE:-0}" == "1" ]]; then
      printf '[%s] gpu_quarantine_reason=%s\n' "${ts}" "${GPU_QUARANTINE_REASON:-active}" >> "${log_file}"
    fi

    if (( SAFE_MODE == 1 )); then
      if command -v notify-send >/dev/null 2>&1; then
        notify-send "Session safe mode enabled" "${SAFE_REASON}" -u normal >/dev/null 2>&1 || true
      fi
    fi

    trim_file "${log_file}" 1000
    ;;
  release-swaync-after-startup-grace)
    load_state
    if [[ -z "${SAFE_MODE:-}" ]]; then
      "${BASH}" "$0" init >/dev/null 2>&1 || true
      load_state
    fi

    ts="$(date '+%F %T %Z')"
    if [[ -f "${diag_disable_swaync_file}" ]]; then
      printf '[%s] swaync_startup_block=kept reason=diagnostic_disable\n' "${ts}" >> "${log_file}"
      trim_file "${log_file}" 1000
      exit 0
    fi

    if [[ "${SAFE_MODE:-0}" == "1" ]]; then
      printf '[%s] swaync_startup_block=kept reason=safe_mode\n' "${ts}" >> "${log_file}"
      trim_file "${log_file}" 1000
      exit 0
    fi

    current_boot_crashes="$(collect_current_boot_crashes)"
    if [[ -n "${current_boot_crashes}" ]]; then
      printf '[%s] swaync_startup_block=kept reason=current_boot_crash_signals\n' "${ts}" >> "${log_file}"
      printf '%s\n' "${current_boot_crashes}" | sed 's/^/[current-boot] /' >> "${log_file}"
      trim_file "${log_file}" 1000
      exit 0
    fi

    rm -f "${startup_disable_swaync_file}"
    printf '[%s] swaync_startup_block=released\n' "${ts}" >> "${log_file}"
    trim_file "${log_file}" 1000

    if ! pgrep -x swaync >/dev/null 2>&1; then
      systemctl --user start swaync.service >/dev/null 2>&1 || swaync >/dev/null 2>&1 &
    fi
    ;;
  print-reason)
    load_state
    printf '%s\n' "${SAFE_REASON:-unknown}"
    ;;
  is-safe-mode)
    load_state
    [[ "${SAFE_MODE:-0}" == "1" ]]
    ;;
  run-shell-if-normal)
    label="${1:-unnamed}"
    shift || true
    shell_fragment="${1:-}"
    if [[ -z "${shell_fragment}" ]]; then
      printf 'Missing shell fragment for %s\n' "${label}" >&2
      exit 2
    fi

    load_state
    if [[ -z "${SAFE_MODE:-}" ]]; then
      "${BASH}" "$0" init >/dev/null 2>&1 || true
      load_state
    fi

    if [[ "${SAFE_MODE:-0}" == "1" ]]; then
      printf '[%s] skip=%s reason=%s\n' "$(date '+%F %T %Z')" "${label}" "${SAFE_REASON:-safe mode}" >> "${log_file}"
      trim_file "${log_file}" 1000
      exit 0
    fi

    exec bash -lc "${shell_fragment}"
    ;;
  run-shell-always)
    label="${1:-unnamed}"
    shift || true
    shell_fragment="${1:-}"
    if [[ -z "${shell_fragment}" ]]; then
      printf 'Missing shell fragment for %s\n' "${label}" >&2
      exit 2
    fi

    load_state
    if [[ -z "${SAFE_MODE:-}" ]]; then
      "${BASH}" "$0" init >/dev/null 2>&1 || true
      load_state
    fi

    if [[ "${SAFE_MODE:-0}" == "1" ]]; then
      printf '[%s] allow=%s safe_mode_reason=%s\n' "$(date '+%F %T %Z')" "${label}" "${SAFE_REASON:-safe mode}" >> "${log_file}"
      trim_file "${log_file}" 1000
    fi

    exec bash -lc "${shell_fragment}"
    ;;
  *)
    printf 'Usage: %s {init|release-swaync-after-startup-grace|print-reason|is-safe-mode|run-shell-if-normal|run-shell-always}\n' "$0" >&2
    exit 2
    ;;
esac
