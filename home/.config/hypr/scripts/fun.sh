#!/usr/bin/env bash
set -euo pipefail

launch_cmd='kitty'

if ! command -v "$launch_cmd" >/dev/null 2>&1; then
  notify-send -u normal "Console Hub" "kitty is required for the workspace 9/10 hacker scene"
  exit 1
fi

kitty_cfg="$HOME/.config/kitty/hacker-scene.conf"

launch_term() {
  local workspace="$1"
  local class_name="$2"
  local title="$3"
  local command_text="$4"
  local escaped
  escaped="$(printf '%q' "$command_text")"
  hyprctl dispatch exec "[workspace ${workspace} silent] ${launch_cmd} --config ${kitty_cfg} --hold --class ${class_name} --title ${title} bash -lc ${escaped}" >/dev/null 2>&1 || true
}

launch_term 9 "fun-matrix" "Matrix" "cmatrix -abBu 2 -C green || exec bash"
sleep 0.15
launch_term 9 "fun-htop" "htop" "htop || exec bash"
sleep 0.15
launch_term 9 "fun-starwars" "StarWars" "$HOME/.config/hypr/scripts/StarWarsTelehack.sh"
sleep 0.15
launch_term 9 "fun-sys" "System" "while true; do clear; fastfetch 2>/dev/null || true; echo; echo '=== Memory ==='; free -h; echo; echo '=== Filesystems ==='; df -hT -x tmpfs -x devtmpfs; echo; echo '=== Processes ==='; procs --sortd cpu 2>/dev/null | sed -n '1,20p' || ps aux --sort=-%cpu | sed -n '1,20p'; sleep 3; done"

sleep 0.25

launch_term 10 "lab-termjam" "Termjam" "$HOME/termjam.py"
sleep 0.15
launch_term 10 "lab-btop" "btop" "btop || exec bash"
sleep 0.15
launch_term 10 "lab-signal" "Signal" "$HOME/.config/hypr/scripts/SignalPulse.sh"
sleep 0.15
launch_term 10 "lab-lazygit" "lazygit" "lazygit || exec bash"
sleep 0.15
launch_term 10 "lab-broot" "broot" "broot || exec bash"

hyprctl dispatch workspace 10 >/dev/null 2>&1 || true
