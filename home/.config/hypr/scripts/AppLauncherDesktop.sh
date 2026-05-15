#!/usr/bin/env bash
set -euo pipefail

open_cmd() {
  local command_text="$1"
  bash -lc "${command_text}" >/dev/null 2>&1 &
}

print_row() {
  local label="$1"
  local icon="$2"
  local info="$3"
  printf '%s\0icon\x1f%s\x1finfo\x1f%s\n' "$label" "$icon" "$info"
}

if [[ "${ROFI_RETV:-0}" -eq 0 ]]; then
  print_row "Obsidian Vault" "obsidian" "obsidian"
  print_row "Browser" "web-browser" "browser"
  print_row "Terminal" "utilities-terminal" "terminal"
  print_row "Files Home" "system-file-manager" "files-home"
  print_row "Downloads" "folder-download" "downloads"
  print_row "Projects" "folder-code" "projects"
  print_row "Clipboard" "edit-paste" "clipboard"
  print_row "Calculator" "accessories-calculator" "calc"
  print_row "Theme Switcher" "preferences-desktop-theme" "theme"
  print_row "Wallpaper Picker" "preferences-desktop-wallpaper" "wallpaper"
  print_row "Keybind Cheatsheet" "input-keyboard" "keys"
  print_row "Script Hub" "system-run" "scripts"
  print_row "Workspace 5 Dashboard" "view-dashboard" "dashboard"
  print_row "Hacker Scene" "utilities-system-monitor" "fun"
  print_row "Overview" "view-grid" "overview"
  print_row "Lock Screen" "system-lock-screen" "lock"
  exit 0
fi

case "${ROFI_INFO:-}" in
  obsidian)
    open_cmd 'obsidian || flatpak run md.obsidian.Obsidian'
    ;;
  browser)
    open_cmd 'zen-browser || firefox || google-chrome-stable || chromium || brave'
    ;;
  terminal)
    open_cmd 'kitty'
    ;;
  files-home)
    open_cmd 'thunar "$HOME" || dolphin "$HOME" || xdg-open "$HOME"'
    ;;
  downloads)
    open_cmd 'thunar "$HOME/Downloads" || dolphin "$HOME/Downloads" || xdg-open "$HOME/Downloads"'
    ;;
  projects)
    open_cmd 'thunar "$HOME" || dolphin "$HOME" || xdg-open "$HOME"'
    ;;
  clipboard)
    open_cmd '"$HOME/.config/hypr/scripts/ClipManager.sh"'
    ;;
  calc)
    open_cmd '"$HOME/.config/hypr/UserScripts/RofiCalc.sh"'
    ;;
  theme)
    open_cmd '"$HOME/.config/hypr/scripts/ThemeChanger.sh"'
    ;;
  wallpaper)
    open_cmd '"$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"'
    ;;
  keys)
    open_cmd '"$HOME/.config/hypr/scripts/KeyBinds.sh"'
    ;;
  scripts)
    open_cmd '"$HOME/.config/hypr/scripts/ScriptHub.sh"'
    ;;
  dashboard)
    open_cmd '"$HOME/.config/hypr/UserScripts/Workspace5Dashboard.sh"'
    ;;
  fun)
    open_cmd '"$HOME/.config/hypr/scripts/fun.sh"'
    ;;
  overview)
    open_cmd '"$HOME/.config/hypr/scripts/OverviewToggle.sh"'
    ;;
  lock)
    open_cmd '"$HOME/.config/hypr/scripts/LockScreen.sh"'
    ;;
esac
