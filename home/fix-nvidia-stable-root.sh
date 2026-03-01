#!/usr/bin/env bash
set -euo pipefail

log() { printf '[fix-nvidia] %s\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo 'Run as root: sudo /home/goringich/fix-nvidia-stable-root.sh'
  exit 1
fi

log 'Current NVIDIA packages:'
pacman -Q | rg -i '(^nvidia|^linux-cachyos.*nvidia|^lib32-nvidia|^opencl-nvidia)' || true

if [[ -e /var/lib/pacman/db.lck ]]; then
  log 'pacman database is locked (/var/lib/pacman/db.lck). Close package managers and rerun.'
  exit 1
fi

log 'Restoring NVIDIA open kernel modules + matching userspace (targeted install)'
pacman -S --needed --noconfirm \
  nvidia-utils lib32-nvidia-utils nvidia-settings \
  opencl-nvidia lib32-opencl-nvidia \
  egl-wayland egl-gbm \
  linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open

if [[ -f /etc/modprobe.d/99-nvidia-stable.conf ]]; then
  log 'Removing old local 580xx tuning override to avoid mixed configs'
  rm -f /etc/modprobe.d/99-nvidia-stable.conf
fi

log 'Rebuilding initramfs'
mkinitcpio -P

log 'Done. Reboot is required.'
log 'After reboot, verify with: nvidia-smi'
