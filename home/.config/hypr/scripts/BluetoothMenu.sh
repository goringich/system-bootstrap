#!/usr/bin/env bash
set -euo pipefail

config="${HOME}/.config/rofi/config-appscope-launcher.rasi"

if pgrep -x rofi >/dev/null 2>&1; then
  pkill rofi
  exit 0
fi

notify() {
  notify-send "Bluetooth" "$1"
}

powered_state() {
  bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}'
}

ensure_powered() {
  if [[ "$(powered_state)" != "yes" ]]; then
    bluetoothctl power on >/dev/null 2>&1 || true
    sleep 1
  fi
}

scan_devices() {
  bluetoothctl --timeout 8 scan on 2>/dev/null || true
}

collect_devices() {
  local scan_output="$1"

  {
    bluetoothctl devices 2>/dev/null | sed 's/^Device //'
    awk '/\[NEW\] Device / {mac=$3; $1=""; $2=""; $3=""; sub(/^ +/, "", $0); print mac " " $0}' <<<"${scan_output}"
  } | awk '!seen[$1]++'
}

format_device_line() {
  local mac="$1"
  local alias="$2"
  local info connected paired trusted battery icon

  info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
  connected="$(awk -F': ' '/Connected:/ {print $2; exit}' <<<"$info")"
  paired="$(awk -F': ' '/Paired:/ {print $2; exit}' <<<"$info")"
  trusted="$(awk -F': ' '/Trusted:/ {print $2; exit}' <<<"$info")"
  battery="$(awk -F': ' '/Battery Percentage:/ {gsub(/[()]/, "", $2); print $2; exit}' <<<"$info")"

  if [[ "$connected" == "yes" ]]; then
    icon="󰂱"
  elif [[ "$paired" == "yes" ]]; then
    icon="󰂯"
  else
    icon="󰂰"
  fi

  local suffix=""
  [[ "$trusted" == "yes" ]] && suffix+=" trusted"
  [[ "$paired" == "yes" ]] && suffix+=" paired"
  [[ -n "$battery" ]] && suffix+=" ${battery}"

  printf "%s  %s [%s]%s\n" "$icon" "$alias" "$mac" "$suffix"
}

device_menu() {
  local scan_output="$1"
  local lines=()

  while IFS= read -r raw; do
    [[ -z "$raw" ]] && continue
    local mac="${raw%% *}"
    local alias="${raw#* }"
    lines+=("$(format_device_line "$mac" "$alias")")
  done < <(collect_devices "${scan_output}")

  {
    printf "󰂯  Rescan\n"
    printf "󰂲  Power Off\n"
    printf "󰂳  Power On\n"
    printf "󰗼  Open Bluetooth Manager\n"
    printf "%s\n" "${lines[@]}"
  } | rofi -dmenu -i -p "Bluetooth" -mesg "Select headphones or rescan nearby devices" -config "$config"
}

handle_device() {
  local line="$1"
  local mac info paired connected
  mac="$(grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' <<<"$line" | head -n1 || true)"
  [[ -z "$mac" ]] && exit 0

  info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
  paired="$(awk -F': ' '/Paired:/ {print $2; exit}' <<<"$info")"
  connected="$(awk -F': ' '/Connected:/ {print $2; exit}' <<<"$info")"

  if [[ "$connected" == "yes" ]]; then
    if bluetoothctl disconnect "$mac" >/dev/null 2>&1; then
      notify "Disconnected ${line#*  }"
    else
      notify "Failed to disconnect ${line#*  }"
    fi
    exit 0
  fi

  if [[ "$paired" != "yes" ]]; then
    bluetoothctl pair "$mac" >/dev/null 2>&1 || true
    bluetoothctl trust "$mac" >/dev/null 2>&1 || true
  fi

  if bluetoothctl connect "$mac" >/dev/null 2>&1; then
    notify "Connected ${line#*  }"
  else
    notify "Failed to connect ${line#*  }"
    exit 1
  fi
}

ensure_powered
scan_output="$(scan_devices)"
selection="$(device_menu "${scan_output}")"
[[ -z "${selection:-}" ]] && exit 0

case "$selection" in
  "󰂯  Rescan")
    ensure_powered
    scan_output="$(scan_devices)"
    selection="$(device_menu "${scan_output}")"
    [[ -z "${selection:-}" ]] && exit 0
    ;;
  "󰂲  Power Off")
    bluetoothctl power off >/dev/null 2>&1 || true
    notify "Bluetooth powered off"
    exit 0
    ;;
  "󰂳  Power On")
    bluetoothctl power on >/dev/null 2>&1 || true
    notify "Bluetooth powered on"
    exit 0
    ;;
  "󰗼  Open Bluetooth Manager")
    exec blueman-manager
    ;;
esac

handle_device "$selection"
