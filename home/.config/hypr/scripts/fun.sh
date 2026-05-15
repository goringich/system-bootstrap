#!/usr/bin/env bash
set -euo pipefail

launch_cmd='kitty'
audio_state_file="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/fun-audio.enabled"

if ! command -v "$launch_cmd" >/dev/null 2>&1; then
  notify-send -u normal "Console Hub" "kitty is required for the workspace 9/10 hacker scene"
  exit 1
fi

cleanup_scene() {
  hyprctl clients -j | jq -r '.[] | select(.class | test("^(fun-|lab-)")) | .address' | while read -r addr; do
    [[ -n "$addr" ]] || continue
    hyprctl dispatch closewindow "address:$addr" >/dev/null 2>&1 || true
  done
}

launch_term() {
  local workspace="$1"
  local class_name="$2"
  local title="$3"
  local command_text="$4"
  local escaped
  escaped="$(printf '%q' "$command_text")"
  hyprctl dispatch exec "[workspace ${workspace} silent] ${launch_cmd} --hold --class ${class_name} --title ${title} -o background=#000000 -o foreground=#00ff5f -o cursor=#00ff5f -o background_opacity=1.0 -o dynamic_background_opacity=no -o window_padding_width=6 bash -lc ${escaped}" >/dev/null 2>&1 || true
}

cleanup_scene
sleep 0.2

launch_term 9 "fun-matrix" "Matrix" "$HOME/.config/hypr/scripts/GreenMatrix.sh"
sleep 0.15
launch_term 9 "fun-cava" "Audio" "cava -p \"$HOME/.config/cava/hacker-scene.conf\" || exec bash"
sleep 0.15
launch_term 9 "fun-htop" "htop" "htop || exec bash"
sleep 0.15
launch_term 9 "fun-cosmic" "Cosmic" "$HOME/.config/hypr/scripts/CosmicGlyphs.sh"
sleep 0.15
launch_term 9 "fun-radar" "Radar" "$HOME/.config/hypr/scripts/SystemRadar.sh"

sleep 0.25

if [[ -f "$audio_state_file" ]]; then
  launch_term 10 "lab-termjam" "Termjam" "TERMJAM_AUDIO=1 \"$HOME/termjam.py\""
else
  launch_term 10 "lab-termjam" "Termjam" "TERMJAM_AUDIO=0 \"$HOME/termjam.py\""
fi
sleep 0.15
launch_term 10 "lab-btop" "btop" "btop || exec bash"
sleep 0.15
launch_term 10 "lab-lazygit" "lazygit" "cd \"$HOME/custom-cachyos-iso\" && lazygit || exec bash"
sleep 0.15
launch_term 10 "lab-broot" "broot" "broot \"$HOME\" || exec bash"

"$HOME/.config/hypr/scripts/ArrangeHackerScene.sh" 1.1 >/dev/null 2>&1 &
hyprctl dispatch workspace 10 >/dev/null 2>&1 || true
