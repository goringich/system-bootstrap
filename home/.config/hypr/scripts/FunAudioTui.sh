#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE_FILE="$STATE_DIR/fun-audio.enabled"
SCENE_SCRIPT="$HOME/.config/hypr/scripts/fun.sh"

mkdir -p "$STATE_DIR"

is_enabled() {
  [[ -f "$STATE_FILE" ]]
}

status_text() {
  if is_enabled; then
    printf 'enabled'
  else
    printf 'disabled'
  fi
}

refresh_scene() {
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    "$SCENE_SCRIPT" >/dev/null 2>&1 &
  fi
}

set_enabled() {
  local mode="$1"
  case "$mode" in
    on)
      touch "$STATE_FILE"
      ;;
    off)
      rm -f "$STATE_FILE"
      ;;
    toggle)
      if is_enabled; then
        rm -f "$STATE_FILE"
      else
        touch "$STATE_FILE"
      fi
      ;;
  esac
}

if [[ "${1:-}" == "--status" ]]; then
  status_text
  exit 0
fi

if [[ "${1:-}" == "--set" ]]; then
  set_enabled "${2:-off}"
  refresh_scene
  exit 0
fi

clear
echo "Fun Audio Control"
echo
echo "Current audio pane: $(status_text)"
echo
echo "e  enable audio pane"
echo "d  disable audio pane"
echo "t  toggle audio pane"
echo "r  rebuild scene"
echo "q  quit"
echo

while true; do
  printf "> "
  IFS= read -r answer || exit 0
  case "$answer" in
    e|E)
      set_enabled on
      refresh_scene
      echo "audio pane enabled"
      ;;
    d|D)
      set_enabled off
      refresh_scene
      echo "audio pane disabled"
      ;;
    t|T)
      set_enabled toggle
      refresh_scene
      echo "audio pane $(status_text)"
      ;;
    r|R)
      refresh_scene
      echo "scene rebuild requested"
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "use: e, d, t, r, q"
      ;;
  esac
done
