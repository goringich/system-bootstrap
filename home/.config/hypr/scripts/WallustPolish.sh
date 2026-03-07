#!/usr/bin/env bash
# Post-process wallust outputs for consistent contrast across UI components.

set -euo pipefail

waybar_colors="$HOME/.config/waybar/wallust/colors-waybar.css"
rofi_colors="$HOME/.config/rofi/wallust/colors-rofi.rasi"

extract_hex_waybar() {
  local key="$1"
  sed -n "s/^\\s*@define-color\\s\\+$key\\s\\+\\(#[0-9A-Fa-f]\\{6\\}\\).*/\\1/p" "$waybar_colors" | head -n1
}

extract_hex_rofi() {
  local key="$1"
  sed -n "s/^\\s*$key:\\s*\\(#[0-9A-Fa-f]\\{6\\}\\).*/\\1/p" "$rofi_colors" | head -n1
}

hex_to_rgb() {
  local hex="${1#\#}"
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  printf '%s %s %s\n' "$r" "$g" "$b"
}

contrast_text_for() {
  local hex="$1"
  local r g b lum
  read -r r g b < <(hex_to_rgb "$hex")
  lum=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
  if (( lum >= 150 )); then
    printf '#111111\n'
  else
    printf '#F5F5F5\n'
  fi
}

if [[ -f "$rofi_colors" ]]; then
  accent="$(extract_hex_rofi color12)"
  [[ -z "$accent" ]] && accent="$(extract_hex_rofi color13)"
  [[ -z "$accent" ]] && accent="#7AA2F7"
  accent_fg="$(contrast_text_for "$accent")"

  bg="$(extract_hex_rofi background-color)"
  [[ -z "$bg" ]] && bg="$(extract_hex_rofi normal-background)"
  [[ -z "$bg" ]] && bg="#121216"
  read -r bg_r bg_g bg_b < <(hex_to_rgb "$bg")

  sed -i -E "s|^(\\s*selected-normal-background:\\s*).*$|\\1$accent;|" "$rofi_colors"
  sed -i -E "s|^(\\s*selected-active-background:\\s*).*$|\\1$accent;|" "$rofi_colors"
  sed -i -E "s|^(\\s*selected-urgent-background:\\s*).*$|\\1$accent;|" "$rofi_colors"
  sed -i -E "s|^(\\s*selected-normal-foreground:\\s*).*$|\\1$accent_fg;|" "$rofi_colors"
  sed -i -E "s|^(\\s*selected-active-foreground:\\s*).*$|\\1$accent_fg;|" "$rofi_colors"
  sed -i -E "s|^(\\s*selected-urgent-foreground:\\s*).*$|\\1$accent_fg;|" "$rofi_colors"
  sed -i -E "s|^(\\s*border-color:\\s*).*$|\\1$accent;|" "$rofi_colors"
  sed -i -E "s|^(\\s*background:\\s*).*$|\\1rgba($bg_r,$bg_g,$bg_b,0.82);|" "$rofi_colors"
fi

if [[ -f "$waybar_colors" ]]; then
  accent="$(extract_hex_waybar color12)"
  [[ -z "$accent" ]] && accent="#7AA2F7"
  accent_fg="$(contrast_text_for "$accent")"

  bg="$(extract_hex_waybar background)"
  [[ -z "$bg" ]] && bg="#121216"
  fg="$(extract_hex_waybar foreground)"
  [[ -z "$fg" ]] && fg="#ECEFF4"

  read -r bg_r bg_g bg_b < <(hex_to_rgb "$bg")
  read -r fg_r fg_g fg_b < <(hex_to_rgb "$fg")
  read -r ac_r ac_g ac_b < <(hex_to_rgb "$accent")

  tmp="$(mktemp)"
  awk '
    BEGIN {skip=0}
    /\/\* wallust-polish:start \*\// {skip=1; next}
    /\/\* wallust-polish:end \*\// {skip=0; next}
    skip==0 {print}
  ' "$waybar_colors" > "$tmp"

  cat >> "$tmp" <<EOF
/* wallust-polish:start */
@define-color wb_surface rgba($bg_r,$bg_g,$bg_b,0.76);
@define-color wb_surface_strong rgba($bg_r,$bg_g,$bg_b,0.90);
@define-color wb_ring rgba($ac_r,$ac_g,$ac_b,0.72);
@define-color wb_glow rgba($ac_r,$ac_g,$ac_b,0.28);
@define-color wb_text $fg;
@define-color wb_text_dim rgba($fg_r,$fg_g,$fg_b,0.76);
@define-color wb_accent $accent;
@define-color wb_accent_alt $(extract_hex_waybar color13);
@define-color wb_accent_fg $accent_fg;
/* wallust-polish:end */
EOF

  # fallback if color13 was missing
  sed -i -E "s/^(@define-color wb_accent_alt )\\s*;$/\\1$accent;/" "$tmp"

  mv "$tmp" "$waybar_colors"
fi
