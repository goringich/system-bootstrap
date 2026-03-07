#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${MANIFEST:-$REPO_ROOT/configs/repos.txt}"
DRY_RUN=0
MODE="update-clean"

usage() {
  cat <<USAGE
Usage: clone-repos.sh [--manifest <file>] [--dry-run] [--mode clone-missing|update-clean]
USAGE
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

expand_path() {
  local raw="$1"
  eval "printf '%s\n' \"$raw\""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --mode) MODE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

command -v git >/dev/null 2>&1 || {
  echo "Missing required command: git" >&2
  exit 1
}

[[ -f "$MANIFEST" ]] || {
  echo "Manifest not found: $MANIFEST" >&2
  exit 1
}

while IFS='|' read -r name repo_url raw_dest branch; do
  [[ -n "${name:-}" ]] || continue
  [[ "$name" =~ ^# ]] && continue

  dest="$(expand_path "$raw_dest")"
  parent_dir="$(dirname "$dest")"

  echo "==> Repo: $name"
  run_cmd mkdir -p "$parent_dir"

  if [[ ! -d "$dest/.git" ]]; then
    clone_args=(clone)
    [[ -n "${branch:-}" ]] && clone_args+=(-b "$branch")
    clone_args+=("$repo_url" "$dest")
    run_cmd git "${clone_args[@]}"
    continue
  fi

  if [[ "$MODE" == "clone-missing" ]]; then
    echo "    exists, skipping update: $dest"
    continue
  fi

  if [[ -n "$(git -C "$dest" status --short 2>/dev/null)" ]]; then
    echo "    dirty repo, skipping update: $dest"
    continue
  fi

  run_cmd git -C "$dest" fetch --all --prune

  target_branch="${branch:-$(git -C "$dest" branch --show-current)}"
  if [[ -n "$target_branch" ]]; then
    run_cmd git -C "$dest" checkout "$target_branch"
    run_cmd git -C "$dest" pull --ff-only origin "$target_branch"
  else
    echo "    no branch detected, skipping pull: $dest"
  fi
done < "$MANIFEST"
