#!/usr/bin/env bash
set -euo pipefail

postgres_url="${POSTGRES_MCP_URL:-${DATABASE_URL:-}}"

if [[ -z "$postgres_url" ]]; then
  echo "Set POSTGRES_MCP_URL or DATABASE_URL before starting the Postgres MCP server." >&2
  exit 1
fi

exec npx -y @modelcontextprotocol/server-postgres "$postgres_url"
