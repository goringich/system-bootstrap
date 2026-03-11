#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
SKIP_REPOS=0
INSTALL_ARGS=()
PROFILE="desktop"
PROFILE_INSTALL_ARGS=()
PROFILE_REPO_MANIFEST="$REPO_ROOT/configs/repos.txt"
REPORT_FILE="${SYSTEM_BOOTSTRAP_REPORT_FILE:-$HOME/.local/state/system-bootstrap/restore-report.txt}"

usage() {
  cat <<USAGE
Usage: bootstrap-host.sh [system-bootstrap install args] [--skip-repos] [--dry-run] [--profile full|desktop|minimal]

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
    --profile)
      PROFILE="$2"
      shift 2
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

profile_file="$REPO_ROOT/configs/profiles/${PROFILE}.sh"
[[ -f "$profile_file" ]] || {
  echo "Unknown profile: $PROFILE" >&2
  exit 1
}
source "$profile_file"

final_install_args=("${PROFILE_INSTALL_ARGS[@]}" "${INSTALL_ARGS[@]}")

echo "==> Applying system-bootstrap"
bash "$REPO_ROOT/install.sh" "${final_install_args[@]}"

if [[ "$SKIP_REPOS" -eq 0 ]]; then
  echo "==> Hydrating workspace repositories"
  repo_args=()
  [[ "$DRY_RUN" -eq 1 ]] && repo_args+=(--dry-run)
  repo_args+=(--manifest "$PROFILE_REPO_MANIFEST")
  bash "$REPO_ROOT/scripts/clone-repos.sh" "${repo_args[@]}"
fi

if [[ -x "$HOME/codex-orchestrator/install.sh" ]]; then
  echo "==> Installing codex-orchestrator into user environment"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] bash %q\n' "$HOME/codex-orchestrator/install.sh"
  else
    bash "$HOME/codex-orchestrator/install.sh"
  fi
fi

if [[ -x "$REPO_ROOT/scripts/restore-audit.sh" ]]; then
  echo "==> Writing restore audit report"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] bash %q %q %q %q\n' \
      "$REPO_ROOT/scripts/restore-audit.sh" \
      "${USER:-goringich}" \
      "$REPORT_FILE" \
      "$HOME"
  else
    mkdir -p "$(dirname "$REPORT_FILE")"
    SYSTEM_BOOTSTRAP_REPO_MANIFEST="$PROFILE_REPO_MANIFEST" \
      bash "$REPO_ROOT/scripts/restore-audit.sh" "${USER:-goringich}" "$REPORT_FILE" "$HOME"
  fi
fi

echo "==> Bootstrap host flow complete"
