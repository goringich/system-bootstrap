#!/usr/bin/env bash
set -euo pipefail

sleep "${1:-0.9}"

monitor_json="$(hyprctl monitors -j | jq 'map(select(.focused))[0] // .[0]')"

mx="$(jq -r '.x' <<<"$monitor_json")"
my="$(jq -r '.y' <<<"$monitor_json")"
mw="$(jq -r '.width' <<<"$monitor_json")"
mh="$(jq -r '.height' <<<"$monitor_json")"
rl="$(jq -r '.reserved[0]' <<<"$monitor_json")"
rt="$(jq -r '.reserved[1]' <<<"$monitor_json")"
rr="$(jq -r '.reserved[2]' <<<"$monitor_json")"
rb="$(jq -r '.reserved[3]' <<<"$monitor_json")"

gap=10
pad=6
ux=$((mx + rl + pad))
uy=$((my + rt + pad))
uw=$((mw - rl - rr - pad * 2))
uh=$((mh - rt - rb - pad * 2))

left_w=$((uw * 37 / 100))
right_w=$((uw - left_w - gap))
stack_w=$((right_w / 2 - gap / 2))
far_w=$((right_w - stack_w - gap))

audio_h=$((uh * 24 / 100))
matrix_h=$((uh - audio_h - gap))
top_h=$((uh * 46 / 100))
radar_h=$((uh - top_h - gap))

termjam_w=$((uw * 47 / 100))
gap10=26
side_w=$((uw - termjam_w - gap10))
btop_h=$((uh * 44 / 100))
lazygit_h=$((uh * 18 / 100))
broot_h=$((uh - btop_h - lazygit_h - gap10 * 2))

clients_json="$(hyprctl clients -j)"

addr_for() {
  local class_name="$1"
  jq -r --arg cls "$class_name" 'map(select(.class == $cls and .mapped == true)) | last | .address // empty' <<<"$clients_json"
}

apply_geom() {
  local class_name="$1"
  local x="$2"
  local y="$3"
  local w="$4"
  local h="$5"
  local addr
  addr="$(addr_for "$class_name")"
  [[ -n "$addr" ]] || return 0
  hyprctl dispatch resizewindowpixel "exact $w $h,address:$addr" >/dev/null 2>&1 || true
  hyprctl dispatch movewindowpixel "exact $x $y,address:$addr" >/dev/null 2>&1 || true
}

# Workspace 9
apply_geom "fun-matrix" "$ux" "$uy" "$left_w" "$matrix_h"
apply_geom "fun-cava" "$ux" "$((uy + matrix_h + gap))" "$left_w" "$audio_h"
apply_geom "fun-audioctl" "$ux" "$((uy + matrix_h + gap))" "$left_w" "$audio_h"
apply_geom "fun-htop" "$((ux + left_w + gap))" "$uy" "$stack_w" "$top_h"
apply_geom "fun-cosmic" "$((ux + left_w + gap + stack_w + gap))" "$uy" "$far_w" "$top_h"
apply_geom "fun-radar" "$((ux + left_w + gap))" "$((uy + top_h + gap))" "$right_w" "$radar_h"

# Workspace 10
apply_geom "lab-termjam" "$ux" "$uy" "$termjam_w" "$uh"
apply_geom "lab-btop" "$((ux + termjam_w + gap10))" "$uy" "$side_w" "$btop_h"
apply_geom "lab-lazygit" "$((ux + termjam_w + gap10))" "$((uy + btop_h + gap10))" "$side_w" "$lazygit_h"
apply_geom "lab-broot" "$((ux + termjam_w + gap10))" "$((uy + btop_h + gap10 + lazygit_h + gap10))" "$side_w" "$broot_h"
