#!/usr/bin/env bash
set -euo pipefail

config="$HOME/.config/rofi/config-appscope-launcher.rasi"

if pgrep -x rofi >/dev/null 2>&1; then
  pkill rofi
  exit 0
fi

rofi \
  -show combi \
  -modi "combi,drun,run,window,filebrowser" \
  -combi-modi "drun,run,window,filebrowser" \
  -show-icons \
  -mesg "apps / commands / windows / files" \
  -config "$config"
