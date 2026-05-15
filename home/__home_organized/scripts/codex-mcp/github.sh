#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
  echo "Set GITHUB_PERSONAL_ACCESS_TOKEN before starting the GitHub MCP server." >&2
  exit 1
fi

args=(run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN)

if [[ -n "${GITHUB_TOOLSETS:-}" ]]; then
  args+=(-e GITHUB_TOOLSETS)
fi

if [[ -n "${GITHUB_READ_ONLY:-}" ]]; then
  args+=(-e GITHUB_READ_ONLY)
fi

args+=(ghcr.io/github/github-mcp-server)

exec docker "${args[@]}"
