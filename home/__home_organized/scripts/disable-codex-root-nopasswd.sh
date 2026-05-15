#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo 'Run as root: sudo /home/goringich/disable-codex-root-nopasswd.sh'
  exit 1
fi

rm -f /etc/sudoers.d/95-goringich-codex
visudo -c

echo 'Removed /etc/sudoers.d/95-goringich-codex'
