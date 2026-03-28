#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/session-windows.tsv"
mkdir -p "$(dirname "$STATE_FILE")"
QUIET=0

if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "hyprctl not found" >&2
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

hyprctl clients -j \
  | jq -r '
      map(
        select(
          .mapped == true
          and .workspace.id > 0
          and .class != null
          and .class != ""
          and (.class | test("^(fun-|lab-)") | not)
        )
      )
      | sort_by(.workspace.id, .class)
      | group_by([.workspace.id, .class])
      | .[]
      | [.[0].workspace.id, .[0].class, (length)]
      | @tsv
    ' > "$tmp_file"

if [[ -f "$STATE_FILE" ]] && cmp -s "$tmp_file" "$STATE_FILE"; then
  (( QUIET == 0 )) && echo "Hypr session snapshot already up to date: $STATE_FILE"
  exit 0
fi

mv "$tmp_file" "$STATE_FILE"
(( QUIET == 0 )) && echo "Saved Hypr session snapshot to: $STATE_FILE"
