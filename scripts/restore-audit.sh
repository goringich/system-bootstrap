#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERNAME="${1:-${USER:-}}"
REPORT_FILE="${2:-}"
TARGET_HOME="${3:-$HOME}"
MANIFEST="${SYSTEM_BOOTSTRAP_REPO_MANIFEST:-$REPO_ROOT/configs/repos.txt}"
SERVICES_MANIFEST="${SYSTEM_BOOTSTRAP_SERVICES_MANIFEST:-$REPO_ROOT/manifests/enabled-services.txt}"

if [[ -z "$USERNAME" ]]; then
  echo "Usage: restore-audit.sh <username> [report-file] [target-home]" >&2
  exit 1
fi

expand_path() {
  local raw="$1"
  HOME="$TARGET_HOME" eval "printf '%s\n' \"$raw\""
}

report() {
  local line="$1"
  printf '%s\n' "$line"
  if [[ -n "$REPORT_FILE" ]]; then
    printf '%s\n' "$line" >> "$REPORT_FILE"
  fi
}

repo_missing=0
repo_dirty=0
repo_branch_gap=0
path_missing=0
service_gap=0
total_gaps=0

if [[ -n "$REPORT_FILE" ]]; then
  mkdir -p "$(dirname "$REPORT_FILE")"
  : > "$REPORT_FILE"
fi

report "Restore verification report"
report "Generated: $(date -Is)"
report "Target home: $TARGET_HOME"
report ""

report "[repos]"
if [[ -f "$MANIFEST" ]]; then
  while IFS='|' read -r name _repo_url raw_dest branch; do
    [[ -n "${name:-}" ]] || continue
    [[ "$name" =~ ^# ]] && continue

    dest="$(expand_path "$raw_dest")"
    if [[ ! -d "$dest/.git" ]]; then
      report "missing  $name -> $dest"
      repo_missing=$((repo_missing + 1))
      total_gaps=$((total_gaps + 1))
      continue
    fi

    if [[ -n "$(git -C "$dest" status --short 2>/dev/null || true)" ]]; then
      report "dirty    $name -> $dest"
      repo_dirty=$((repo_dirty + 1))
      total_gaps=$((total_gaps + 1))
      continue
    fi

    current_branch="$(git -C "$dest" branch --show-current 2>/dev/null || true)"
    expected_branch="${branch:-$current_branch}"
    if [[ -n "$expected_branch" && -n "$current_branch" && "$expected_branch" != "$current_branch" ]]; then
      report "branch   $name -> current=$current_branch expected=$expected_branch"
      repo_branch_gap=$((repo_branch_gap + 1))
      total_gaps=$((total_gaps + 1))
      continue
    fi

    report "ok       $name -> $dest"
  done < "$MANIFEST"
else
  report "skip     manifest not found: $MANIFEST"
fi

report ""
report "[paths]"
key_paths=(
  ".config/hypr"
  ".config/rofi"
  ".config/waybar"
  ".config/systemd/user"
  ".local/bin"
)

for rel_path in "${key_paths[@]}"; do
  if [[ -e "$TARGET_HOME/$rel_path" ]]; then
    report "ok       $rel_path"
  else
    report "missing  $rel_path"
    path_missing=$((path_missing + 1))
    total_gaps=$((total_gaps + 1))
  fi
done

report ""
report "[user-services]"
if [[ -f "$SERVICES_MANIFEST" ]] && command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r svc; do
    [[ -n "${svc:-}" ]] || continue
    [[ "$svc" =~ ^# ]] && continue

    if systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
      report "ok       $svc"
    else
      report "disabled $svc"
      service_gap=$((service_gap + 1))
      total_gaps=$((total_gaps + 1))
    fi
  done < "$SERVICES_MANIFEST"
else
  report "skip     user service manifest unavailable"
fi

report ""
report "[summary]"
report "repo_missing=$repo_missing"
report "repo_dirty=$repo_dirty"
report "repo_branch_gap=$repo_branch_gap"
report "path_missing=$path_missing"
report "service_gap=$service_gap"
report "total_gaps=$total_gaps"
