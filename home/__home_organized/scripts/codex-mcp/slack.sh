#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
  echo "Set SLACK_BOT_TOKEN before starting the Slack MCP server." >&2
  exit 1
fi

exec npx -y @modelcontextprotocol/server-slack
