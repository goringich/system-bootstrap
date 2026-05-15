#!/usr/bin/env bash
set -euo pipefail

owner_user="${SUDO_USER:-goringich}"
owner_home="$(getent passwd "${owner_user}" | cut -d: -f6)"
backup_root="${owner_home}/__home_organized/artifacts/system-safety"
runtime_root="${owner_home}/__home_organized/runtime/system-safety-backup"
max_backups=14
ts="$(date '+%F_%H-%M-%S')"
latest_link="${backup_root}/latest"
mkdir -p "${backup_root}" "${runtime_root}"
workdir="$(mktemp -d "${runtime_root}/backup-${ts}-XXXXXX")"

cleanup() {
  rm -rf "${workdir}"
}
trap cleanup EXIT

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -e "${src}" ]]; then
    install -D -m 644 "${src}" "${workdir}/${dst}"
  fi
}

copy_tree_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -d "${src}" ]]; then
    mkdir -p "${workdir}/${dst}"
    cp -a "${src}/." "${workdir}/${dst}/"
  fi
}

copy_if_exists "/boot/limine.conf" "boot/limine.conf"
copy_if_exists "/etc/systemd/journald.conf.d/99-persistent-journal.conf" "etc/systemd/journald.conf.d/99-persistent-journal.conf"
copy_if_exists "/etc/systemd/system/btrfs-scrub-root.service" "etc/systemd/system/btrfs-scrub-root.service"
copy_if_exists "/etc/systemd/system/btrfs-scrub-root.timer" "etc/systemd/system/btrfs-scrub-root.timer"
copy_if_exists "/etc/pacman.d/hooks/95-system-safety-audit.hook" "etc/pacman.d/hooks/95-system-safety-audit.hook"
copy_tree_if_exists "${owner_home}/.config/hypr/UserConfigs" "home/.config/hypr/UserConfigs"
copy_tree_if_exists "${owner_home}/.config/systemd/user" "home/.config/systemd/user"
copy_tree_if_exists "${owner_home}/.local/share/applications" "home/.local/share/applications"
copy_tree_if_exists "${owner_home}/__home_organized/scripts" "home/__home_organized/scripts"
copy_if_exists "${owner_home}/SYSTEM_DEBUG_START_HERE.md" "home/SYSTEM_DEBUG_START_HERE.md"

tarball="${backup_root}/system-safety-${ts}.tar.zst"
tar --zstd -cf "${tarball}" -C "${workdir}" .
ln -sfn "${tarball}" "${latest_link}"
find "${backup_root}" -maxdepth 1 -type d -name 'backup-*' -exec rm -rf {} +
find "${backup_root}" -maxdepth 1 -type f -name 'system-safety-*.tar.zst' | sort -r | awk "NR>${max_backups}" | xargs -r rm -f
chown -R "${owner_user}:${owner_user}" "${backup_root}"
chown -R "${owner_user}:${owner_user}" "${runtime_root}"

printf 'Created safety backup: %s\n' "${tarball}"
