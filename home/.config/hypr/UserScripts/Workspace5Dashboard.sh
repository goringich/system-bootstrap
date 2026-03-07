#!/usr/bin/env bash
set -euo pipefail

# Opens a monitoring dashboard on workspace 5:
# - btop
# - htop
# - system overview (cpu/mem/disk/tree)
# - optional animated pane (cmatrix)

term_cmd="kitty"
if ! command -v kitty >/dev/null 2>&1; then
  term_cmd="alacritty"
fi
if ! command -v "$term_cmd" >/dev/null 2>&1; then
  term_cmd="foot"
fi

if ! command -v "$term_cmd" >/dev/null 2>&1; then
  echo "No supported terminal found (kitty/alacritty/foot)." >&2
  exit 1
fi

run_on_ws5() {
  local cmd="$1"
  hyprctl dispatch exec "[workspace 5 silent] $cmd" >/dev/null 2>&1 || true
}

run_on_ws5 "$term_cmd --class dash-btop --title dash-btop -e btop"
sleep 0.2
run_on_ws5 "$term_cmd --class dash-htop --title dash-htop -e htop"
sleep 0.2
run_on_ws5 "$term_cmd --class dash-sys --title dash-sys -e bash -lc 'while true; do clear; fastfetch 2>/dev/null || true; echo; echo \"=== Memory ===\"; free -h; echo; echo \"=== Filesystems ===\"; df -hT -x tmpfs -x devtmpfs; echo; echo \"=== Block Devices ===\"; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS; echo; echo \"=== /home tree (depth 2) ===\"; tree -L 2 "$HOME" 2>/dev/null | sed -n \"1,80p\"; sleep 2; done'"

if command -v cmatrix >/dev/null 2>&1; then
  sleep 0.2
  run_on_ws5 "$term_cmd --class dash-anim --title dash-anim -e cmatrix -abs"
fi

hyprctl dispatch workspace 5 >/dev/null 2>&1 || true
