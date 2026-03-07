#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/session-windows.tsv"
mkdir -p "$(dirname "$STATE_FILE")"

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "hyprctl not found" >&2
  exit 1
fi

hyprctl clients -j \
  | jq -r '
      map(select(.workspace.id > 0 and .class != null and .class != ""))
      | sort_by(.workspace.id, .class)
      | group_by([.workspace.id, .class])
      | .[]
      | [.[0].workspace.id, .[0].class, (length)]
      | @tsv
    ' > "$STATE_FILE"

echo "Saved Hypr session snapshot to: $STATE_FILE"
