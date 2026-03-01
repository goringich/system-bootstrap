#!/usr/bin/env bash
set -euo pipefail

sudo /home/goringich/enable-codex-root-nopasswd.sh
sudo /home/goringich/fix-nvidia-stable-root.sh

echo 'All done. Reboot now: sudo reboot'
