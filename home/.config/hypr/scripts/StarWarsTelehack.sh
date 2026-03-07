#!/usr/bin/env bash
set -euo pipefail

if ! command -v telnet >/dev/null 2>&1; then
  exec "$HOME/.config/hypr/scripts/LocalStarfield.sh"
fi

run_telehack() {
  bash -lc '{ sleep 1; printf "starwars\r"; cat; } | telnet telehack.com 23'
}

run_blinkenlights() {
  telnet towel.blinkenlights.nl 23
}

run_telehack || run_blinkenlights || exec "$HOME/.config/hypr/scripts/LocalStarfield.sh"
