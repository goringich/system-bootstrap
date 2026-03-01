#!/usr/bin/env bash
# Robust logout helper for Hyprland sessions started in different ways
# (SDDM, TTY, nested shells, or missing XDG_SESSION_ID).

set -euo pipefail

# Preferred path: ask Hyprland to exit cleanly.
if command -v hyprctl >/dev/null 2>&1; then
    if hyprctl -j monitors >/dev/null 2>&1; then
        hyprctl dispatch exit
        exit 0
    fi
fi

# Fallback: terminate the current user session via logind.
session_id="${XDG_SESSION_ID:-}"
if [[ -z "$session_id" ]] && command -v loginctl >/dev/null 2>&1; then
    session_id="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER" '$3 == u {print $1; exit}')"
fi

if [[ -n "${session_id:-}" ]] && command -v loginctl >/dev/null 2>&1; then
    loginctl terminate-session "$session_id"
    exit 0
fi

# Last resort: terminate all sessions for current user.
if command -v loginctl >/dev/null 2>&1; then
    loginctl terminate-user "$USER"
    exit 0
fi

# Emergency fallback if logind is unavailable.
pkill -x Hyprland || true
