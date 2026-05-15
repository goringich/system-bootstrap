#!/usr/bin/env bash
set -euo pipefail

owner_user="${SUDO_USER:-goringich}"
owner_home="$(getent passwd "${owner_user}" | cut -d: -f6)"
backup_root="${owner_home}/__home_organized/artifacts/system-safety"
restore_root="${owner_home}/__home_organized/runtime/system-safety-restore"

usage() {
  cat <<'EOF'
Usage:
  system-safety-restore.sh list
  system-safety-restore.sh verify [latest|/path/to/archive.tar.zst]
  system-safety-restore.sh extract [latest|/path/to/archive.tar.zst]

This script is non-destructive. It only lists, verifies, or extracts
backups into ~/__home_organized/runtime/system-safety-restore/.
EOF
}

resolve_archive() {
  local arg="${1:-latest}"
  if [[ "${arg}" == "latest" ]]; then
    readlink -f "${backup_root}/latest"
  else
    readlink -f "${arg}"
  fi
}

cmd="${1:-}"
case "${cmd}" in
  list)
    mkdir -p "${backup_root}"
    ls -lh "${backup_root}" | tail -n 20
    ;;
  verify)
    archive="$(resolve_archive "${2:-latest}")"
    [[ -f "${archive}" ]] || { echo "Backup archive not found: ${archive}"; exit 1; }
    tar --zstd -tf "${archive}" >/dev/null
    printf 'Verified backup archive: %s\n' "${archive}"
    ;;
  extract)
    archive="$(resolve_archive "${2:-latest}")"
    [[ -f "${archive}" ]] || { echo "Backup archive not found: ${archive}"; exit 1; }
    stamp="$(date '+%F_%H-%M-%S')"
    target="${restore_root}/restore-${stamp}"
    mkdir -p "${target}"
    tar --zstd -xf "${archive}" -C "${target}"
    printf 'Extracted backup archive to: %s\n' "${target}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
