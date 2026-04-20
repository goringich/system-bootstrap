#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${LOCAL_ONLY_REPOS_FILE:-$REPO_ROOT/configs/local-only-repos.txt}"
OWNER="${GITHUB_OWNER:-goringich}"
DRY_RUN=0
PRIVATE_FLAG="--private"

usage() {
  cat <<USAGE
Usage: publish-local-only-repos.sh [--dry-run] [--public]

Publishes local-only repos marked decision=publish in configs/local-only-repos.txt.
Requires a valid gh auth session with repo creation permission.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --public) PRIVATE_FLAG="--public" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

expand_path() {
  local raw="$1"
  HOME="${HOME:?}" eval "printf '%s\n' \"$raw\""
}

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

require_clean_or_confirmed() {
  local repo_path="$1"
  if [[ -n "$(git -C "$repo_path" status --short)" ]]; then
    echo "Refusing dirty repo: $repo_path" >&2
    git -C "$repo_path" status --short >&2
    return 1
  fi
}

check_secret_patterns() {
  local repo_path="$1"
  local pattern='(ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY)'
  if git -C "$repo_path" grep -nIE "$pattern" -- .; then
    echo "Refusing repo with secret-like material: $repo_path" >&2
    return 1
  fi
}

command -v gh >/dev/null 2>&1 || {
  echo "Missing gh CLI" >&2
  exit 1
}

if [[ "$DRY_RUN" -eq 0 ]]; then
  gh auth status >/dev/null
fi

while IFS='|' read -r name raw_path visibility decision _reason; do
  [[ -n "${name:-}" ]] || continue
  [[ "$name" =~ ^# ]] && continue
  [[ "$decision" == "publish" ]] || continue

  repo_path="$(expand_path "$raw_path")"
  [[ -d "$repo_path/.git" ]] || {
    echo "Skipping missing git repo: $repo_path" >&2
    continue
  }

  require_clean_or_confirmed "$repo_path"
  check_secret_patterns "$repo_path"

  remote_url="git@github.com:${OWNER}/${name}.git"
  current_branch="$(git -C "$repo_path" branch --show-current)"

  if ! git -C "$repo_path" remote get-url origin >/dev/null 2>&1; then
    run_cmd git -C "$repo_path" remote add origin "$remote_url"
  fi

  if ! gh repo view "${OWNER}/${name}" >/dev/null 2>&1; then
    if [[ "$visibility" == "public" ]]; then
      run_cmd gh repo create "${OWNER}/${name}" --public --source "$repo_path" --remote origin
    else
      run_cmd gh repo create "${OWNER}/${name}" "$PRIVATE_FLAG" --source "$repo_path" --remote origin
    fi
  fi

  run_cmd env GIT_SSH_COMMAND='ssh -F /dev/null' git -C "$repo_path" push -u origin "$current_branch"
done < "$CONFIG_FILE"
