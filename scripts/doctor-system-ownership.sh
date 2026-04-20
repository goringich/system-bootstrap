#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
FIX=0

usage() {
  cat <<USAGE
Usage: doctor-system-ownership.sh [--fix] [--dry-run]

Checks the root-owned system paths that must not drift to nobody:nobody.
Use --fix from a real root shell or recovery shell to repair the current fault.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix) FIX=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

paths=(
  /etc/sudo.conf
  /etc/sudoers
  /etc/sudoers.d
  /etc/ssh
  /etc/ssh/ssh_config
  /etc/ssh/ssh_config.d
  /usr/lib/systemd/ssh_config.d
  /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf
)

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

echo "==> Current ownership"
for path in "${paths[@]}"; do
  [[ -e "$path" || -L "$path" ]] || continue
  stat -c '%U:%G %a %n' "$path"
done

if [[ "$FIX" -eq 0 ]]; then
  echo "==> Check only. Re-run with --fix from root to repair."
  exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Refusing to fix without root. Use a real root shell or recovery environment." >&2
  exit 1
fi

echo "==> Repairing root-owned metadata"
for path in "${paths[@]}"; do
  [[ -e "$path" || -L "$path" ]] || continue
  if [[ -L "$path" ]]; then
    run_cmd chown -h root:root "$path"
  else
    run_cmd chown root:root "$path"
  fi
done

[[ -d /etc/ssh ]] && run_cmd chmod 755 /etc/ssh
[[ -d /etc/ssh/ssh_config.d ]] && run_cmd chmod 755 /etc/ssh/ssh_config.d
[[ -f /etc/sudo.conf ]] && run_cmd chmod 644 /etc/sudo.conf
[[ -f /etc/sudoers ]] && run_cmd chmod 440 /etc/sudoers
[[ -d /etc/sudoers.d ]] && run_cmd chmod 750 /etc/sudoers.d
[[ -d /usr/lib/systemd/ssh_config.d ]] && run_cmd chmod 755 /usr/lib/systemd/ssh_config.d
[[ -f /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf ]] && run_cmd chmod 644 /usr/lib/systemd/ssh_config.d/20-systemd-ssh-proxy.conf

echo "==> Repaired ownership"
for path in "${paths[@]}"; do
  [[ -e "$path" || -L "$path" ]] || continue
  stat -c '%U:%G %a %n' "$path"
done
