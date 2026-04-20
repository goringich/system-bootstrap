#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="${SCAN_ROOT:-$HOME}"
DOC_OUT="${DOC_OUT:-$REPO_ROOT/docs/repo-inventory.md}"
MANIFEST_OUT="${MANIFEST_OUT:-$REPO_ROOT/configs/repos-all.txt}"
EXCLUDES_FILE="${REPO_INVENTORY_EXCLUDES_FILE:-$REPO_ROOT/configs/repo-inventory-excludes.txt}"

classify_repo() {
  local path="$1"
  local remote="$2"

  if [[ "$remote" == git@github.com:goringich/* || "$remote" == https://github.com/goringich/* ]]; then
    printf 'personal-github\n'
    return
  fi

  if [[ "$remote" == git@github.com:* || "$remote" == https://github.com/* || "$remote" == https://aur.archlinux.org/* ]]; then
    printf 'external-upstream\n'
    return
  fi

  if [[ -n "$remote" ]]; then
    printf 'other-remote\n'
    return
  fi

  printf 'local-only\n'
}

repo_name_from_remote() {
  local remote="$1"
  local name="${remote##*/}"
  name="${name%.git}"
  printf '%s\n' "$name"
}

infer_branch() {
  local path="$1"
  local branch

  branch="$(git -C "$path" branch --show-current 2>/dev/null || true)"
  if [[ -n "$branch" ]]; then
    printf '%s\n' "$branch"
    return
  fi

  branch="$(git -C "$path" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  branch="${branch#origin/}"
  printf '%s\n' "${branch:-main}"
}

tmp_inventory="$(mktemp)"
trap 'rm -f "$tmp_inventory"' EXIT

is_excluded_repo_path() {
  local path="$1"
  local pattern

  [[ -f "$EXCLUDES_FILE" ]] || return 1
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    [[ "$pattern" =~ ^# ]] && continue
    pattern="${pattern/#\$HOME/$HOME}"
    pattern="${pattern/#~/$HOME}"
    [[ "$path" == "$pattern" || "$path" == "$pattern"/* ]] && return 0
  done < "$EXCLUDES_FILE"

  return 1
}

while IFS= read -r gitdir; do
  path="$(dirname "$gitdir")"
  is_excluded_repo_path "$path" && continue
  remote="$(git -C "$path" remote get-url origin 2>/dev/null || true)"
  branch="$(git -C "$path" branch --show-current 2>/dev/null || true)"
  dirty="$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  category="$(classify_repo "$path" "$remote")"
  printf '%s|%s|%s|%s|%s\n' "$path" "$remote" "$branch" "$dirty" "$category" >> "$tmp_inventory"
done < <(
  find "$SCAN_ROOT" \
    \( -path "$SCAN_ROOT/.cache" -o -path "$SCAN_ROOT/.cargo" -o -path "$SCAN_ROOT/.codex" -o -path "$SCAN_ROOT/.local/share/Trash" -o -path "$SCAN_ROOT/.pub-cache" -o -path "$SCAN_ROOT/.var" -o -path "$SCAN_ROOT/fvm" \) -prune -o \
    -name .git -type d -print 2>/dev/null | sort
)

mkdir -p "$(dirname "$DOC_OUT")" "$(dirname "$MANIFEST_OUT")"

{
  printf '# repo-inventory\n\n'
  printf 'Generated: `%s`\n\n' "$(date -Is)"
  printf 'Scan root: `%s`\n\n' "$SCAN_ROOT"

  total_count="$(wc -l < "$tmp_inventory" | tr -d ' ')"
  personal_count="$(awk -F'|' '$5=="personal-github"{count++} END{print count+0}' "$tmp_inventory")"
  external_count="$(awk -F'|' '$5=="external-upstream"{count++} END{print count+0}' "$tmp_inventory")"
  local_count="$(awk -F'|' '$5=="local-only"{count++} END{print count+0}' "$tmp_inventory")"
  other_count="$(awk -F'|' '$5=="other-remote"{count++} END{print count+0}' "$tmp_inventory")"

  printf '## Summary\n\n'
  printf -- '- total repos: `%s`\n' "$total_count"
  printf -- '- personal GitHub repos: `%s`\n' "$personal_count"
  printf -- '- external upstream repos: `%s`\n' "$external_count"
  printf -- '- local-only repos: `%s`\n' "$local_count"
  printf -- '- other remotes: `%s`\n\n' "$other_count"

  printf '## Personal GitHub Repos\n\n'
  if ! awk -F'|' '$5=="personal-github"{exit 1}' "$tmp_inventory"; then
    :
  fi
  awk -F'|' '$5=="personal-github"' "$tmp_inventory" | sort | while IFS='|' read -r path remote branch dirty _category; do
    printf -- '- `%s` -> `%s` -> branch `%s` -> dirty `%s`\n' "$path" "$remote" "${branch:-detached}" "$dirty"
  done
  printf '\n## External Upstream Repos\n\n'
  awk -F'|' '$5=="external-upstream"' "$tmp_inventory" | sort | while IFS='|' read -r path remote branch dirty _category; do
    printf -- '- `%s` -> `%s` -> branch `%s` -> dirty `%s`\n' "$path" "$remote" "${branch:-detached}" "$dirty"
  done

  printf '\n## Local-Only Repos\n\n'
  awk -F'|' '$5=="local-only"' "$tmp_inventory" | sort | while IFS='|' read -r path remote branch dirty _category; do
    printf -- '- `%s` -> branch `%s` -> dirty `%s`\n' "$path" "${branch:-detached}" "$dirty"
  done

  printf '\n## Restore Risks\n\n'
  awk -F'|' '$5=="personal-github" && $4 != "0"' "$tmp_inventory" | sort | while IFS='|' read -r path remote branch dirty _category; do
    printf -- '- dirty personal repo: `%s` -> `%s` -> branch `%s` -> dirty `%s`\n' "$path" "$remote" "${branch:-detached}" "$dirty"
  done
  awk -F'|' '$2 ~ /goringich\/-\.git$/ {print $1 "|" $2 "|" $3 "|" $4}' "$tmp_inventory" | while IFS='|' read -r path remote branch dirty; do
    printf -- '- suspicious remote naming: `%s` -> `%s` -> branch `%s` -> dirty `%s`\n' "$path" "$remote" "${branch:-detached}" "$dirty"
  done

  printf '\n## Notes\n\n'
  printf -- '- `personal-github` repos can be hydrated by `restore-my-system` without extra decisions.\n'
  printf -- '- `external-upstream` repos should stay documented, but not treated as your personal source of truth.\n'
  printf -- '- `local-only` repos are the main blockers for true 1:1 GitHub-backed restore until they get remotes or are intentionally retired.\n'
  printf -- '- Bluetooth recovery for the onboard Foxconn `0489:e10a` adapter is part of the canonical restore path in `system-bootstrap` via `system/`, `configs/system-paths.txt`, and `docs/bluetooth-foxconn-e10a-runbook.md`.\n'
} > "$DOC_OUT"

{
  printf '# name|repo_url|destination|branch\n'
  awk -F'|' '$5=="personal-github"' "$tmp_inventory" | sort | while IFS='|' read -r path remote branch _dirty _category; do
    name="$(repo_name_from_remote "$remote")"
    rel_path="${path#$HOME/}"
    if [[ "$path" == "$HOME" ]]; then
      dest="\$HOME"
    else
      dest="\$HOME/$rel_path"
    fi
    printf '%s|%s|%s|%s\n' "$name" "$remote" "$dest" "$(infer_branch "$path")"
  done
} > "$MANIFEST_OUT"

printf 'Wrote %s and %s\n' "$DOC_OUT" "$MANIFEST_OUT"
