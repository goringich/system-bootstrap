#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo 'Run as root: sudo /home/goringich/enable-codex-root-nopasswd.sh'
  exit 1
fi

cat > /etc/sudoers.d/95-goringich-codex <<'EOSUDO'
# Allow Codex-driven maintenance without interactive password prompts.
# Remove with: sudo rm -f /etc/sudoers.d/95-goringich-codex
Defaults:goringich !requiretty

goringich ALL=(ALL:ALL) NOPASSWD: ALL
EOSUDO

chmod 440 /etc/sudoers.d/95-goringich-codex
visudo -cf /etc/sudoers.d/95-goringich-codex

echo 'Enabled passwordless sudo for goringich via /etc/sudoers.d/95-goringich-codex'
