#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
archive_dir="${HOME}/__home_organized/logs/hyprland-runtime"
state_dir="${HOME}/.local/state/hyprland-log-guard"
activity_log="${archive_dir}/hyprland-log-guard.log"
max_live_bytes="${HYPRLAND_LOG_GUARD_MAX_BYTES:-134217728}"
max_archives="${HYPRLAND_LOG_GUARD_MAX_ARCHIVES:-20}"
max_age_days="${HYPRLAND_LOG_GUARD_MAX_AGE_DAYS:-30}"

mkdir -p "${archive_dir}" "${state_dir}"

log_event() {
  printf '[%s] %s\n' "$(date '+%F %T %Z')" "$*" >> "${activity_log}"
}

pick_compressor() {
  if command -v zstd >/dev/null 2>&1; then
    printf 'zstd'
  elif command -v gzip >/dev/null 2>&1; then
    printf 'gzip'
  else
    printf 'cat'
  fi
}

compress_file() {
  local src="$1"
  local compressor="$2"

  case "${compressor}" in
    zstd)
      zstd -T0 -10 -q -f "${src}" -o "${src}.zst"
      rm -f "${src}"
      printf '%s\n' "${src}.zst"
      ;;
    gzip)
      gzip -9 -f "${src}"
      printf '%s\n' "${src}.gz"
      ;;
    *)
      printf '%s\n' "${src}"
      ;;
  esac
}

trim_activity_log() {
  local max_lines=1000
  [[ -f "${activity_log}" ]] || return 0
  local lines
  lines="$(wc -l < "${activity_log}")"
  if (( lines > max_lines )); then
    tail -n "${max_lines}" "${activity_log}" > "${activity_log}.tmp"
    mv "${activity_log}.tmp" "${activity_log}"
  fi
}

cleanup_archives() {
  find "${archive_dir}" -maxdepth 1 -type f \
    ! -name "$(basename "${activity_log}")" \
    \( -name '*.zst' -o -name '*.gz' -o -name '*.log' \) \
    -mtime "+${max_age_days}" -delete 2>/dev/null || true

  mapfile -t archives < <(
    find "${archive_dir}" -maxdepth 1 -type f \
      ! -name "$(basename "${activity_log}")" \
      \( -name '*.zst' -o -name '*.gz' -o -name '*.log' \) \
      -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2}'
  )

  if (( ${#archives[@]} > max_archives )); then
    for old_file in "${archives[@]:max_archives}"; do
      rm -f "${old_file}"
      log_event "removed old archive ${old_file}"
    done
  fi
}

archive_log_if_needed() {
  local log_file="$1"
  local size allocated block_size
  size="$(stat -c '%s' "${log_file}")"
  allocated="$(stat -c '%b' "${log_file}")"
  block_size="$(stat -c '%B' "${log_file}")"
  allocated="$(( allocated * block_size ))"
  if (( allocated <= max_live_bytes )); then
    return 0
  fi

  local instance_id stamp copied archived
  instance_id="$(basename "$(dirname "${log_file}")")"
  stamp="$(date '+%F_%H-%M-%S')"
  copied="${archive_dir}/${stamp}-${instance_id}-hyprland.log"

  cp --reflink=auto --sparse=always "${log_file}" "${copied}" 2>/dev/null || cp "${log_file}" "${copied}"
  archived="$(compress_file "${copied}" "$(pick_compressor)")"

  : > "${log_file}"

  log_event "archived ${log_file} apparent_size=${size} allocated_bytes=${allocated} archive=${archived}"
}

if [[ ! -d "${runtime_dir}" ]]; then
  cleanup_archives
  trim_activity_log
  exit 0
fi

while IFS= read -r log_file; do
  archive_log_if_needed "${log_file}"
done < <(find "${runtime_dir}" -maxdepth 2 -type f -name 'hyprland.log' -print 2>/dev/null | sort)

cleanup_archives
trim_activity_log
