#!/usr/bin/env bash
set -euo pipefail

if HOME="${HOME:-/home/goringich}" docker mcp gateway --help >/dev/null 2>&1; then
  exec docker mcp gateway run
fi

echo "Docker MCP Gateway is not installed in the local Docker CLI yet." >&2
echo "Install the Docker MCP plugin, then re-run this server." >&2
exit 1
