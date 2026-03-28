#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/session-windows.tsv"

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "hyprctl not found" >&2
  exit 1
fi

term_cmd="kitty"
if ! command -v kitty >/dev/null 2>&1; then
  term_cmd="alacritty"
fi
if ! command -v "$term_cmd" >/dev/null 2>&1; then
  term_cmd="foot"
fi

command_for_class() {
  local class="$1"
  case "$class" in
    code-url-handler|Code|code-oss|code|com.visualstudio.code)
      echo "sh -lc '/app/bin/code || code || code-oss || codium'"
      ;;
    google-chrome|Google-chrome|Google-chrome-stable|google-chrome-stable|Chromium|chromium)
      echo "$HOME/.local/bin/google-chrome-stable --restore-last-session"
      ;;
    firefox|Firefox)
      echo "firefox"
      ;;
    TelegramDesktop|telegram-desktop|Telegram|org.telegram.desktop)
      echo "sh -lc 'Telegram || telegram-desktop || telegram'"
      ;;
    obsidian|Obsidian)
      echo "sh -lc 'obsidian || flatpak run md.obsidian.Obsidian'"
      ;;
    kitty)
      echo "$term_cmd"
      ;;
    thunar|Thunar)
      echo "thunar"
      ;;
    org.pulseaudio.pavucontrol|Pavucontrol)
      echo "pavucontrol"
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ ! -s "$STATE_FILE" ]]; then
  notify-send -u low "Hypr session restore" "No saved window snapshot found yet"
  exit 0
fi

while IFS=$'\t' read -r ws class count; do
  [[ -z "$ws" || -z "$class" || -z "$count" ]] && continue

  cmd=""
  if cmd="$(command_for_class "$class")"; then
    i=0
    while (( i < count )); do
      hyprctl dispatch exec "[workspace $ws silent] $cmd" >/dev/null 2>&1 || true
      i=$((i + 1))
      sleep 0.15
    done
  else
    echo "Skip class without restore mapping: $class (workspace $ws, count $count)"
  fi
done < "$STATE_FILE"

echo "Session restore command batch sent from: $STATE_FILE"
