#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests"
HOME_SNAPSHOT_DIR="$REPO_ROOT/home"
TARGET_HOME="${TARGET_HOME:-$HOME}"

usage() {
  cat <<USAGE
Usage: ./install.sh [--skip-packages] [--skip-aur] [--skip-configs] [--skip-services]
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-aur) SKIP_AUR=1 ;;
    --skip-configs) SKIP_CONFIGS=1 ;;
    --skip-services) SKIP_SERVICES=1 ;;
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

if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
  echo "==> Installing repo packages (non-system)"
  if [[ -s "$MANIFESTS_DIR/pacman-explicit-non-system.txt" ]]; then
    sudo pacman -Syu --noconfirm
    mapfile -t pkg_list < "$MANIFESTS_DIR/pacman-explicit-non-system.txt"
    if [[ "${#pkg_list[@]}" -gt 0 ]]; then
      sudo pacman -S --needed --noconfirm "${pkg_list[@]}"
    fi
  fi
fi

if [[ "$SKIP_AUR" -eq 0 ]]; then
  if [[ -s "$MANIFESTS_DIR/aur-explicit.txt" ]]; then
    if ! command -v yay >/dev/null 2>&1; then
      echo "==> Installing yay"
      tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT
      git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
      (cd "$tmp_dir/yay" && makepkg -si --noconfirm)
      trap - EXIT
      rm -rf "$tmp_dir"
    fi

    echo "==> Installing AUR packages"
    mapfile -t aur_list < "$MANIFESTS_DIR/aur-explicit.txt"
    if [[ "${#aur_list[@]}" -gt 0 ]]; then
      yay -S --needed --noconfirm "${aur_list[@]}"
    fi
  fi
fi

if [[ "$SKIP_CONFIGS" -eq 0 ]]; then
  echo "==> Restoring home configuration snapshot"
  if [[ -d "$HOME_SNAPSHOT_DIR" ]]; then
    rsync -a "$HOME_SNAPSHOT_DIR/" "$TARGET_HOME/"
  fi
fi

if [[ "$SKIP_SERVICES" -eq 0 ]]; then
  echo "==> Enabling captured systemd services"
  if [[ -s "$MANIFESTS_DIR/enabled-services.txt" ]]; then
    while IFS= read -r svc; do
      [[ -n "$svc" ]] || continue
      sudo systemctl enable "$svc" || true
    done < "$MANIFESTS_DIR/enabled-services.txt"
  fi
fi

echo "==> Done"
