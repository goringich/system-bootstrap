#!/usr/bin/env bash
set -euo pipefail

repo_url="${DOCKER_MCP_REPO_URL:-https://github.com/docker/mcp-gateway.git}"
tmp_dir="$(mktemp -d)"
plugin_dir="${HOME}/.docker/cli-plugins"
plugin_path="${plugin_dir}/docker-mcp"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
command -v go >/dev/null 2>&1 || { echo "go is required" >&2; exit 1; }
command -v make >/dev/null 2>&1 || { echo "make is required" >&2; exit 1; }

git clone --depth 1 "$repo_url" "$tmp_dir/mcp-gateway"
cd "$tmp_dir/mcp-gateway"
mkdir -p "$plugin_dir"
make docker-mcp
[[ -x "$plugin_path" ]] || install -m 755 ./dist/docker-mcp "$plugin_path"
echo "Installed docker-mcp to $plugin_path"
docker mcp --help >/dev/null
echo "docker mcp is now available"
