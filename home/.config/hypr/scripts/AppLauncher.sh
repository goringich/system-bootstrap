#!/usr/bin/env bash
set -euo pipefail

config="$HOME/.config/rofi/config-appscope-launcher.rasi"
desktop_mode="desk:$HOME/.config/hypr/scripts/AppLauncherDesktop.sh"

if pgrep -x rofi >/dev/null 2>&1; then
  pkill rofi
  exit 0
fi

rofi \
  -show combi \
  -modi "combi,$desktop_mode,drun,run,window,filebrowser" \
  -combi-modi "drun,run,window,filebrowser" \
  -show-icons \
  -mesg "desktop shortcuts  |  apps  |  commands  |  windows  |  files" \
  -config "$config"
