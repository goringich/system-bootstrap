#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests"
HOME_SNAPSHOT_DIR="$REPO_ROOT/home"
INCLUDE_FILE="$REPO_ROOT/scripts/include-paths.txt"
EXCLUDE_SYSTEM_FILE="$REPO_ROOT/manifests/system-package-exclude.txt"
SOURCE_HOME="${SOURCE_HOME:-$HOME}"

if [[ "$(id -u)" -eq 0 && -z "${SOURCE_HOME_OVERRIDE:-}" ]]; then
  if [[ -n "${SUDO_USER:-}" ]]; then
    SOURCE_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  elif [[ -d "/home/goringich" ]]; then
    SOURCE_HOME="/home/goringich"
  fi
fi

mkdir -p "$MANIFESTS_DIR" "$HOME_SNAPSHOT_DIR"

echo "==> Capturing package manifests"
pacman -Qqen | sort -u > "$MANIFESTS_DIR/pacman-explicit-full.txt"
pacman -Qqem | sort -u > "$MANIFESTS_DIR/aur-explicit.txt"

if [[ -f "$EXCLUDE_SYSTEM_FILE" ]]; then
  grep -vxF -f "$EXCLUDE_SYSTEM_FILE" "$MANIFESTS_DIR/pacman-explicit-full.txt" > "$MANIFESTS_DIR/pacman-explicit-non-system.txt"
else
  cp "$MANIFESTS_DIR/pacman-explicit-full.txt" "$MANIFESTS_DIR/pacman-explicit-non-system.txt"
fi

echo "==> Capturing enabled systemd services from /etc/systemd/system"
find /etc/systemd/system -maxdepth 2 -type l -name '*.service' -printf '%f\n' \
  | sort -u > "$MANIFESTS_DIR/enabled-services.txt"

echo "==> Capturing home config snapshot"
find "$HOME_SNAPSHOT_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  [[ "$path" =~ ^# ]] && continue
  src="$SOURCE_HOME/$path"
  if [[ -e "$src" ]]; then
    dst="$HOME_SNAPSHOT_DIR/$path"
    if [[ -d "$src" ]]; then
      mkdir -p "$dst"
      rsync -a "$src/" "$dst/"
    else
      mkdir -p "$HOME_SNAPSHOT_DIR/$(dirname "$path")"
      rsync -a "$src" "$dst"
    fi
  fi
done < "$INCLUDE_FILE"

echo "==> Capture complete"
