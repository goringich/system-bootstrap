#!/usr/bin/env bash
set -euo pipefail

db_path="${SQLITE_MCP_DB_PATH:-$HOME/__home_organized/runtime/codex/sqlite/codex-tools.db}"
mkdir -p "$(dirname "$db_path")"

exec npx -y @modelcontextprotocol/server-sqlite --db-path "$db_path"
