#!/usr/bin/env bash
set -euo pipefail

args=(-y @upstash/context7-mcp)

if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
  args+=(--api-key "$CONTEXT7_API_KEY")
fi

exec npx "${args[@]}"
