#!/usr/bin/env bash
set -euo pipefail

echo '=== Packages ==='
pacman -Q | rg -i '(^nvidia|^linux-cachyos.*nvidia|^lib32-nvidia|^dkms)' || true

echo
echo '=== nvidia-smi ==='
nvidia-smi || true

echo
echo '=== Driver Version ==='
cat /proc/driver/nvidia/version || true

echo
echo '=== Boot NVIDIA errors ==='
journalctl -b --no-pager | rg -i 'nvrm|xid|gsp|reset required|nvidia-modeset|nvml' || true
