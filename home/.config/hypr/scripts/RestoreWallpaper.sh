#!/usr/bin/env bash
set -euo pipefail

wallpaper_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_copy="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
scripts_dir="$HOME/.config/hypr/scripts"
session_env_file="$HOME/.config/hypr/session.env"
quarantine_file="$HOME/.local/state/gpu-watchdog/quarantine.env"

if [[ -f "$session_env_file" ]]; then
  # Reuse the live Hyprland session environment when this script is launched
  # from a shell or service that did not inherit Wayland variables.
  # shellcheck disable=SC1090
  source "$session_env_file"
fi

if [[ -f "$quarantine_file" ]]; then
  # shellcheck disable=SC1090
  source "$quarantine_file"
  if [[ "${GPU_QUARANTINE:-0}" == "1" ]]; then
    exit 0
  fi
fi

pick_wallpaper() {
  if [[ -L "$wallpaper_link" && -f "$wallpaper_link" ]]; then
    readlink -f "$wallpaper_link"
    return 0
  fi

  if [[ -f "$wallpaper_copy" ]]; then
    printf '%s\n' "$wallpaper_copy"
    return 0
  fi

  return 1
}

wallpaper_path="$(pick_wallpaper || true)"
if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
  exit 0
fi

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
  awww-daemon --format xrgb >/dev/null 2>&1 &
  sleep 0.5
fi

focused_monitor=""
if command -v jq >/dev/null 2>&1; then
  monitors_json="$(hyprctl monitors -j 2>/dev/null || true)"
  if [[ "${monitors_json}" == \[* ]]; then
    focused_monitor="$(printf '%s\n' "${monitors_json}" | jq -r '.[] | select(.focused) | .name' 2>/dev/null | head -n 1)"
  fi
fi
if [[ -z "${focused_monitor}" ]]; then
  focused_monitor="$(hyprctl monitors 2>/dev/null | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}' || true)"
fi

transition_args=(
  --transition-fps 60
  --transition-type any
  --transition-duration 2
  --transition-bezier .43,1.19,1,.4
)

if [[ -n "${focused_monitor}" ]]; then
  awww img --outputs "${focused_monitor}" "${wallpaper_path}" "${transition_args[@]}" >/dev/null 2>&1 || true
else
  awww img "${wallpaper_path}" "${transition_args[@]}" >/dev/null 2>&1 || true
fi

"${scripts_dir}/WallustSwww.sh" "${wallpaper_path}" >/dev/null 2>&1 || true
