#!/usr/bin/env bash
set -euo pipefail

SAVE_SCRIPT="$HOME/.config/hypr/UserScripts/SessionSave.sh"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-session-autosave.pid"
INTERVAL="${HYPR_SESSION_AUTOSAVE_INTERVAL:-20}"

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi

echo "$$" > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT INT TERM

sleep 6

while true; do
  "$SAVE_SCRIPT" --quiet >/dev/null 2>&1 || true
  sleep "$INTERVAL"
done
