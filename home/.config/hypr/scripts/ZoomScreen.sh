#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-}"
STEP="${HYPR_ZOOM_STEP:-1.20}"
MIN_ZOOM="${HYPR_ZOOM_MIN:-1.00}"
MAX_ZOOM="${HYPR_ZOOM_MAX:-16.00}"
LOG_DIR="${HOME}/__home_organized/logs"
LOG_FILE="${LOG_DIR}/hypr-zoom.log"

mkdir -p "${LOG_DIR}"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"${LOG_FILE}"
}

get_zoom() {
  hyprctl getoption cursor:zoom_factor | awk 'NR==1 { printf "%.2f", $2 }'
}

before="$(get_zoom)"

case "${ACTION}" in
  in)
    after="$(awk -v current="${before}" -v step="${STEP}" -v max="${MAX_ZOOM}" 'BEGIN { value = current * step; if (value > max) value = max; printf "%.2f", value }')"
    ;;
  out)
    after="$(awk -v current="${before}" -v step="${STEP}" -v min="${MIN_ZOOM}" 'BEGIN { value = current / step; if (value < min) value = min; printf "%.2f", value }')"
    ;;
  reset)
    after="$(printf "%.2f" "${MIN_ZOOM}")"
    ;;
  *)
    log "invalid action=${ACTION}"
    exit 1
    ;;
esac

hyprctl keyword cursor:zoom_factor "${after}" >/dev/null
applied="$(get_zoom)"
log "action=${ACTION} before=${before} target=${after} applied=${applied}"

if command -v notify-send >/dev/null 2>&1; then
  notify-send \
    -a Hyprland \
    -h string:x-canonical-private-synchronous:hypr-screen-zoom \
    "Screen zoom" \
    "${applied}x"
fi
