#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests"
HOME_SNAPSHOT_DIR="$REPO_ROOT/home"
SYSTEM_SNAPSHOT_DIR="$REPO_ROOT/system"
TARGET_HOME="${TARGET_HOME:-$HOME}"

usage() {
  cat <<USAGE
Usage: ./install.sh [--skip-packages] [--skip-aur] [--skip-configs] [--skip-services] [--skip-system-overlay] [--dry-run] [--no-backup]
USAGE
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

SKIP_PACKAGES=0
SKIP_AUR=0
SKIP_CONFIGS=0
SKIP_SERVICES=0
SKIP_SYSTEM_OVERLAY=0
DRY_RUN=0
DO_BACKUP=1
BACKUP_ROOT="${BACKUP_ROOT:-$TARGET_HOME/.system-bootstrap-backups}"
BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-aur) SKIP_AUR=1 ;;
    --skip-configs) SKIP_CONFIGS=1 ;;
    --skip-services) SKIP_SERVICES=1 ;;
    --skip-system-overlay) SKIP_SYSTEM_OVERLAY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-backup) DO_BACKUP=0 ;;
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

need_cmd sudo
need_cmd pacman
need_cmd rsync

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

preflight_check() {
  [[ -d "$TARGET_HOME" ]] || {
    echo "Target home does not exist: $TARGET_HOME" >&2
    exit 1
  }

  if [[ "$SKIP_AUR" -eq 0 && ! -s "$MANIFESTS_DIR/aur-explicit.txt" ]]; then
    echo "==> No AUR manifest found, skipping AUR install"
    SKIP_AUR=1
  fi
}

backup_existing_configs() {
  [[ "$DO_BACKUP" -eq 1 ]] || return 0
  [[ -d "$HOME_SNAPSHOT_DIR" ]] || return 0

  BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%d-%H%M%S)"
  mapfile -t backup_paths < <(find "$HOME_SNAPSHOT_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
  [[ "${#backup_paths[@]}" -gt 0 ]] || return 0

  echo "==> Backing up existing target files to $BACKUP_DIR"
  run_cmd mkdir -p "$BACKUP_DIR"

  local path
  for path in "${backup_paths[@]}"; do
    [[ -e "$TARGET_HOME/$path" ]] || continue
    run_cmd rsync -aR "$TARGET_HOME/$path" "$BACKUP_DIR/"
  done
}

preflight_check

if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
  echo "==> Installing repo packages (non-system)"
  if [[ -s "$MANIFESTS_DIR/pacman-explicit-non-system.txt" ]]; then
    run_cmd sudo pacman -Syu --noconfirm
    mapfile -t pkg_list < "$MANIFESTS_DIR/pacman-explicit-non-system.txt"
    if [[ "${#pkg_list[@]}" -gt 0 ]]; then
      run_cmd sudo pacman -S --needed --noconfirm "${pkg_list[@]}"
    fi
  fi
fi

if [[ "$SKIP_AUR" -eq 0 ]]; then
  if [[ -s "$MANIFESTS_DIR/aur-explicit.txt" ]]; then
    if ! command -v yay >/dev/null 2>&1; then
      echo "==> Installing yay"
      tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT
      run_cmd git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
      if [[ "$DRY_RUN" -eq 0 ]]; then
        (cd "$tmp_dir/yay" && makepkg -si --noconfirm)
      fi
      trap - EXIT
      rm -rf "$tmp_dir"
    fi

    echo "==> Installing AUR packages"
    mapfile -t aur_list < "$MANIFESTS_DIR/aur-explicit.txt"
    if [[ "${#aur_list[@]}" -gt 0 ]]; then
      run_cmd yay -S --needed --noconfirm "${aur_list[@]}"
    fi
  fi
fi

if [[ "$SKIP_CONFIGS" -eq 0 ]]; then
  echo "==> Restoring home configuration snapshot"
  if [[ -d "$HOME_SNAPSHOT_DIR" ]]; then
    backup_existing_configs
    run_cmd rsync -a "$HOME_SNAPSHOT_DIR/" "$TARGET_HOME/"
  fi
fi

if [[ "$SKIP_SYSTEM_OVERLAY" -eq 0 ]]; then
  echo "==> Restoring system overlay snapshot"
  if [[ -d "$SYSTEM_SNAPSHOT_DIR" ]]; then
    run_cmd sudo rsync -a "$SYSTEM_SNAPSHOT_DIR/" /
  fi
fi

if [[ "$SKIP_SERVICES" -eq 0 ]]; then
  echo "==> Enabling captured systemd services"
  if [[ -s "$MANIFESTS_DIR/enabled-services.txt" ]]; then
    while IFS= read -r svc; do
      [[ -n "$svc" ]] || continue
      run_cmd sudo systemctl enable "$svc" || true
    done < "$MANIFESTS_DIR/enabled-services.txt"
  fi
fi

echo "==> Done"
