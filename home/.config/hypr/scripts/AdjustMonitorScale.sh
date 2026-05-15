#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-}"
MONITORS_CONF="${HOME}/.config/hypr/monitors.conf"
LOG_DIR="${HOME}/__home_organized/logs"
RUNTIME_DIR="${HOME}/__home_organized/runtime/hypr-scaling"
STATE_FILE="${RUNTIME_DIR}/current.env"
LOG_FILE="${LOG_DIR}/hypr-monitor-scale.log"

mkdir -p "${LOG_DIR}" "${RUNTIME_DIR}"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"${LOG_FILE}"
}

if [[ -z "${ACTION}" ]]; then
  printf 'usage: %s <up|down|reset>\n' "${0##*/}" >&2
  exit 1
fi

if ! command -v hyprctl >/dev/null 2>&1; then
  printf 'hyprctl is required\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required\n' >&2
  exit 1
fi

monitor_json="$(hyprctl monitors -j | jq 'map(select(.focused))[0] // .[0]')"

if [[ -z "${monitor_json}" || "${monitor_json}" == "null" ]]; then
  printf 'no active monitor found\n' >&2
  exit 1
fi

name="$(jq -r '.name' <<<"${monitor_json}")"
width="$(jq -r '.width' <<<"${monitor_json}")"
height="$(jq -r '.height' <<<"${monitor_json}")"
x_pos="$(jq -r '.x' <<<"${monitor_json}")"
y_pos="$(jq -r '.y' <<<"${monitor_json}")"
monitor_scale="$(jq -r '.scale' <<<"${monitor_json}")"
refresh="$(jq -r '(.refreshRate // .refresh // 60)' <<<"${monitor_json}")"

# This monitor/compositor pair quantizes scale aggressively. Keep only the
# clearly distinct plateaus so each hotkey press produces a visible change.
declare -a SCALE_STEPS=("0.80" "0.85" "0.90" "0.95" "1.00" "1.25" "1.33" "1.60" "1.78" "2.00")

scale="${monitor_scale}"
if [[ -f "${STATE_FILE}" ]]; then
  # For sub-1.0 pseudo scaling, the monitor stays at 1.00 while app scale
  # carries the smaller effective value. Reuse that logical value for stepping.
  source "${STATE_FILE}"
  if [[ "${HYPR_SCALE_MODE:-}" == "pseudo" && -n "${HYPR_APP_SCALE:-}" ]]; then
    scale="${HYPR_APP_SCALE}"
  fi
fi

nearest_index=0
nearest_diff="$(awk -v current="${scale}" -v candidate="${SCALE_STEPS[0]}" 'BEGIN { d = current - candidate; if (d < 0) d = -d; printf "%.6f", d }')"
for idx in "${!SCALE_STEPS[@]}"; do
  diff="$(awk -v current="${scale}" -v candidate="${SCALE_STEPS[$idx]}" 'BEGIN { d = current - candidate; if (d < 0) d = -d; printf "%.6f", d }')"
  if awk -v left="${diff}" -v right="${nearest_diff}" 'BEGIN { exit !(left < right) }'; then
    nearest_index="${idx}"
    nearest_diff="${diff}"
  fi
done

case "${ACTION}" in
  up)
    target_index=$(( nearest_index + 1 ))
    if (( target_index >= ${#SCALE_STEPS[@]} )); then
      target_index=$(( ${#SCALE_STEPS[@]} - 1 ))
    fi
    new_scale="${SCALE_STEPS[$target_index]}"
    ;;
  down)
    target_index=$(( nearest_index - 1 ))
    if (( target_index < 0 )); then
      target_index=0
    fi
    new_scale="${SCALE_STEPS[$target_index]}"
    ;;
  reset)
    new_scale="1.00"
    ;;
  *)
    printf 'unknown action: %s\n' "${ACTION}" >&2
    exit 1
    ;;
esac

refresh_fmt="$(awk -v value="${refresh}" 'BEGIN { printf "%.2f", value }')"
mode="${width}x${height}@${refresh_fmt}"
position="${x_pos}x${y_pos}"
monitor_target="${new_scale}"
app_target="${new_scale}"

if awk -v value="${new_scale}" 'BEGIN { exit !(value < 1.0) }'; then
  monitor_target="1.00"
fi

hyprctl keyword monitor "${name},${mode},${position},${monitor_target}" >/dev/null

get_applied_monitor_scale() {
  hyprctl monitors -j | jq -r --arg name "${name}" '.[] | select(.name == $name) | .scale' | awk 'NR==1 { printf "%.2f", $1 }'
}

applied_monitor_scale="${monitor_scale}"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 0.15
  applied_monitor_scale="$(get_applied_monitor_scale)"
  if [[ "${applied_monitor_scale}" == "${monitor_target}" ]]; then
    break
  fi
done

applied_scale="${new_scale}"
scale_mode="monitor"
if [[ "${monitor_target}" != "${new_scale}" ]]; then
  scale_mode="pseudo"
fi

if [[ -f "${MONITORS_CONF}" ]]; then
  tmp_file="$(mktemp)"
  awk -F',' -v OFS=',' -v target_name="${name}" -v target_scale="${applied_monitor_scale}" '
    BEGIN {
      updated = 0
    }
    /^[[:space:]]*monitor[[:space:]]*=/ {
      current_name = $1
      sub(/^[[:space:]]*monitor[[:space:]]*=[[:space:]]*/, "", current_name)
      if (current_name == target_name && NF >= 4) {
        $4 = target_scale
        updated = 1
      }
    }
    {
      print
    }
    END {
      if (updated == 0) {
        exit 3
      }
    }
  ' "${MONITORS_CONF}" >"${tmp_file}" && mv "${tmp_file}" "${MONITORS_CONF}" || rm -f "${tmp_file}"
fi

if [[ -x "${HOME}/.config/hypr/scripts/SyncAppScaling.sh" ]]; then
  if ! "${HOME}/.config/hypr/scripts/SyncAppScaling.sh" "${applied_scale}" "${applied_monitor_scale}" "${scale_mode}" >/dev/null 2>&1; then
    log "warning=sync-app-scaling-failed applied=${applied_scale}"
  fi
fi

log "action=${ACTION} monitor=${name} before=${scale} nearest=${SCALE_STEPS[$nearest_index]} target=${new_scale} monitor_target=${monitor_target} applied_monitor=${applied_monitor_scale} applied=${applied_scale} scale_mode=${scale_mode} mode=${mode} position=${position}"

if command -v notify-send >/dev/null 2>&1; then
  notify-send \
    -a Hyprland \
    -h string:x-canonical-private-synchronous:hypr-monitor-scale \
    "Screen scale" \
    "${name}: ${applied_scale}x"
fi
