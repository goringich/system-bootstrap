#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
SKIP_REPOS=0
INSTALL_ARGS=()

usage() {
  cat <<USAGE
Usage: bootstrap-host.sh [system-bootstrap install args] [--skip-repos] [--dry-run]

Examples:
  ./bin/restore-my-system --dry-run --skip-packages --skip-aur
  ./bin/restore-my-system --skip-aur
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      INSTALL_ARGS+=("$1")
      shift
      ;;
    --skip-repos)
      SKIP_REPOS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      INSTALL_ARGS+=("$1")
      shift
      ;;
  esac
done

echo "==> Applying system-bootstrap"
bash "$REPO_ROOT/install.sh" "${INSTALL_ARGS[@]}"

if [[ "$SKIP_REPOS" -eq 0 ]]; then
  echo "==> Hydrating workspace repositories"
  repo_args=()
  [[ "$DRY_RUN" -eq 1 ]] && repo_args+=(--dry-run)
  bash "$REPO_ROOT/scripts/clone-repos.sh" "${repo_args[@]}"
fi

echo "==> Bootstrap host flow complete"
