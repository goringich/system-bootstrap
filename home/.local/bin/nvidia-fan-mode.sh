#!/usr/bin/env bash
set -euo pipefail

mode="${1:-manual}"
speed="${2:-35}"

xauth_file="$(sudo -n find /run/sddm -maxdepth 1 -type f -name 'xauth_*' 2>/dev/null | head -n1 || true)"
if [[ -z "$xauth_file" ]]; then
  echo "No readable SDDM Xauthority file found in /run/sddm"
  exit 1
fi

if [[ "$mode" == "auto" ]]; then
  sudo -n env DISPLAY=:0 XAUTHORITY="$xauth_file" \
    nvidia-settings -a '[gpu:0]/GPUFanControlState=0' >/dev/null
else
  if ! [[ "$speed" =~ ^[0-9]+$ ]] || (( speed < 30 || speed > 100 )); then
    echo "Invalid speed '$speed' (allowed 30-100)"
    exit 1
  fi

  sudo -n env DISPLAY=:0 XAUTHORITY="$xauth_file" \
    nvidia-settings \
      -a '[gpu:0]/GPUFanControlState=1' \
      -a "[fan:0]/GPUTargetFanSpeed=${speed}" \
      -a "[fan:1]/GPUTargetFanSpeed=${speed}" >/dev/null
fi

sudo -n env DISPLAY=:0 XAUTHORITY="$xauth_file" \
  nvidia-settings -q '[gpu:0]/GPUFanControlState' -q '[fan:0]/GPUCurrentFanSpeed' -q '[fan:1]/GPUCurrentFanSpeed' \
  | sed -n '1,120p'
