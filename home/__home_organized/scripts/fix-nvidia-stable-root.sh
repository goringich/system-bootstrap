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

log 'Restoring NVIDIA 580xx open kernel modules + matching userspace (targeted install)'
pacman -S --needed --noconfirm \
  nvidia-580xx-open-dkms nvidia-580xx-utils nvidia-580xx-settings \
  egl-wayland egl-gbm

log 'Writing NVIDIA suspend/resume stability override'
cat > /etc/modprobe.d/99-nvidia-stability.conf <<'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp NVreg_EnableGpuFirmware=0 NVreg_DynamicPowerManagement=0x00 NVreg_EnableS0ixPowerManagement=0 NVreg_InitializeSystemMemoryAllocations=1
EOF

log 'Rebuilding initramfs and updating Limine entries'
limine-mkinitcpio

log 'Done. Reboot is required.'
log 'After reboot, verify with: nvidia-smi'
