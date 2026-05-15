#!/usr/bin/env bash
set -euo pipefail

HOME_ROOT="${HOME_ROOT:-$HOME}"
BOOTSTRAP_ROOT="${SYSTEM_BOOTSTRAP_ROOT:-$HOME_ROOT/system-bootstrap}"
INCLUDE_FILE="$BOOTSTRAP_ROOT/scripts/include-paths.txt"
REPO_MANIFEST="${SYSTEM_BOOTSTRAP_REPO_MANIFEST:-$BOOTSTRAP_ROOT/configs/repos-all.txt}"
RULES_FILE="${SYSTEM_CONTROL_RULES_FILE:-$BOOTSTRAP_ROOT/configs/system-control-rules.txt}"
SYSTEM_REPOS_FILE="${SYSTEM_REPOS_FILE:-$BOOTSTRAP_ROOT/configs/system-repos.txt}"
SYSTEM_CONTROL_REPO_SCOPE="${SYSTEM_CONTROL_REPO_SCOPE:-system}"
RUNTIME_ROOT="${HOME_ROOT}/__home_organized/runtime/system-control"
LOG_ROOT="${HOME_ROOT}/__home_organized/logs"
DOC_OUT="${BOOTSTRAP_ROOT}/docs/system-control-catalog.md"
LATEST_REPORT="${LOG_ROOT}/system-control-latest.md"
MAX_LOGS=20
MODE="full"
SYNC_DOCS=0
FOCUS="all"

usage() {
  cat <<'EOF'
system-control

Usage:
  system-control
  system-control --compact
  system-control --full
  system-control --focus repos|promote|review|noise|secrets|uncovered
  system-control --sync-docs
  system-control --help

What it audits:
  - personal GitHub repos vs external vs local-only repos
  - Now / Promote / Review / Noise lanes instead of one flat dump
  - live paths already captured in system-bootstrap or personal repos
  - declared snapshot paths still missing from the git mirror
  - uncovered live paths outside personal git coverage
  - secret-risk traces such as PATs in config/history artifacts

Outputs:
  - runtime dashboard in ~/__home_organized/logs/system-control-latest.md
  - tracked catalog in ~/system-bootstrap/docs/system-control-catalog.md
EOF
}

expand_path() {
  local raw="$1"
  HOME="$HOME_ROOT" eval "printf '%s\n' \"$raw\""
}

is_system_repo_path() {
  local path="$1"
  local _name raw_path _role _tier abs

  [[ "$SYSTEM_CONTROL_REPO_SCOPE" == "system" ]] || return 0
  [[ -f "$SYSTEM_REPOS_FILE" ]] || return 1

  while IFS='|' read -r _name raw_path _role _tier; do
    [[ -n "${_name:-}" ]] || continue
    [[ "$_name" =~ ^# ]] && continue
    abs="$(expand_path "$raw_path")"
    [[ "$path" == "$abs" ]] && return 0
  done < "$SYSTEM_REPOS_FILE"

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compact) MODE="compact"; shift ;;
    --full) MODE="full"; shift ;;
    --focus) FOCUS="${2:-all}"; shift 2 ;;
    --sync-docs) SYNC_DOCS=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "$RUNTIME_ROOT" "$LOG_ROOT"

stamp="$(date '+%F_%H-%M-%S')"
report_file="${LOG_ROOT}/system-control-${stamp}.md"
tmp_dir="$(mktemp -d "${RUNTIME_ROOT}/run-${stamp}-XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

managed_paths_file="${tmp_dir}/managed-paths.txt"
config_candidates_file="${tmp_dir}/config-candidates.txt"
bin_candidates_file="${tmp_dir}/bin-candidates.txt"
desktop_candidates_file="${tmp_dir}/desktop-candidates.txt"
script_candidates_file="${tmp_dir}/script-candidates.txt"
repo_scan_file="${tmp_dir}/repo-scan.tsv"
captured_file="${tmp_dir}/captured.txt"
declared_missing_file="${tmp_dir}/declared-missing.txt"
uncovered_file="${tmp_dir}/uncovered.txt"
external_only_file="${tmp_dir}/external-only.txt"
local_only_file="${tmp_dir}/local-only.txt"
secret_risk_file="${tmp_dir}/secret-risk.txt"
promote_file="${tmp_dir}/promote.txt"
review_file="${tmp_dir}/review.txt"
noise_file="${tmp_dir}/noise.txt"

touch \
  "$managed_paths_file" \
  "$config_candidates_file" \
  "$bin_candidates_file" \
  "$desktop_candidates_file" \
  "$script_candidates_file" \
  "$repo_scan_file" \
  "$captured_file" \
  "$declared_missing_file" \
  "$uncovered_file" \
  "$external_only_file" \
  "$local_only_file" \
  "$secret_risk_file" \
  "$promote_file" \
  "$review_file" \
  "$noise_file"

write_if_changed() {
  local path="$1"
  local content_file="$2"
  local current=""

  [[ -f "$path" ]] && current="$(cat "$path")"
  [[ "$current" == "$(cat "$content_file")" ]] && return 1
  mkdir -p "$(dirname "$path")"
  cat "$content_file" > "$path"
  return 0
}

rule_bucket_for() {
  local rel="$1"
  local bucket pattern reason

  [[ -f "$RULES_FILE" ]] || {
    printf 'unclassified|\n'
    return
  }

  while IFS='|' read -r bucket pattern reason; do
    [[ -n "$bucket" ]] || continue
    [[ "$bucket" =~ ^# ]] && continue
    if [[ "$rel" == "$pattern" || "$rel" == "$pattern"* ]]; then
      printf '%s|%s\n' "$bucket" "$reason"
      return
    fi
  done < "$RULES_FILE"

  printf 'unclassified|\n'
}

has_managed_parent() {
  local rel="$1"
  while IFS= read -r managed; do
    [[ -n "$managed" ]] || continue
    if [[ "$rel" == "$managed" || "$rel" == "$managed/"* ]]; then
      return 0
    fi
  done < "$managed_paths_file"
  return 1
}

repo_category() {
  local abs="$1"
  local repo_root remote

  repo_root="$(git -C "$(dirname "$abs")" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$repo_root" ]]; then
    printf 'none|-\n'
    return
  fi

  remote="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  if [[ "$remote" == git@github.com:goringich/* || "$remote" == https://github.com/goringich/* ]]; then
    printf 'personal|%s\n' "$repo_root"
    return
  fi
  if [[ -n "$remote" ]]; then
    printf 'external|%s\n' "$repo_root"
    return
  fi
  printf 'local-only|%s\n' "$repo_root"
}

snapshot_mirror_exists() {
  local rel="$1"
  [[ -e "$BOOTSTRAP_ROOT/home/$rel" ]]
}

record_uncovered_lane() {
  local rel="$1"
  local rule_info bucket reason

  rule_info="$(rule_bucket_for "$rel")"
  bucket="${rule_info%%|*}"
  reason="${rule_info#*|}"

  case "$bucket" in
    promote) printf '%s|%s\n' "$rel" "$reason" >> "$promote_file" ;;
    review) printf '%s|%s\n' "$rel" "$reason" >> "$review_file" ;;
    noise) printf '%s|%s\n' "$rel" "$reason" >> "$noise_file" ;;
    *) : ;;
  esac
}

classify_candidate() {
  local rel="$1"
  local abs="$HOME_ROOT/$rel"
  local repo_info category repo_root rule_info bucket reason

  repo_info="$(repo_category "$abs")"
  category="${repo_info%%|*}"
  repo_root="${repo_info#*|}"

  if [[ "$category" == "personal" ]]; then
    printf '%s|personal-repo|%s\n' "$rel" "$repo_root" >> "$captured_file"
    return
  fi

  if has_managed_parent "$rel"; then
    if snapshot_mirror_exists "$rel"; then
      printf '%s|system-bootstrap|%s\n' "$rel" "$BOOTSTRAP_ROOT" >> "$captured_file"
    else
      rule_info="$(rule_bucket_for "$rel")"
      bucket="${rule_info%%|*}"
      reason="${rule_info#*|}"
      case "$bucket" in
        promote) printf '%s|%s\n' "$rel" "$reason" >> "$promote_file" ;;
        review) printf '%s|%s\n' "$rel" "$reason" >> "$review_file" ;;
        noise) printf '%s|%s\n' "$rel" "$reason" >> "$noise_file" ;;
        *) printf '%s|declared-not-captured|%s\n' "$rel" "$BOOTSTRAP_ROOT/home/$rel" >> "$declared_missing_file" ;;
      esac
    fi
    return
  fi

  case "$category" in
    external)
      printf '%s|external-repo-only|%s\n' "$rel" "$repo_root" >> "$external_only_file"
      ;;
    local-only)
      printf '%s|local-only-repo|%s\n' "$rel" "$repo_root" >> "$local_only_file"
      ;;
    *)
      printf '%s|uncovered|-\n' "$rel" >> "$uncovered_file"
      record_uncovered_lane "$rel"
      ;;
  esac
}

print_split_list() {
  local file="$1"
  local limit="${2:-0}"
  local count=0
  while IFS='|' read -r left right _rest; do
    [[ -n "$left" ]] || continue
    count=$((count + 1))
    if (( limit > 0 && count > limit )); then
      break
    fi
    if [[ -n "${right:-}" ]]; then
      printf -- '- `%s` -> %s\n' "$left" "$right"
    else
      printf -- '- `%s`\n' "$left"
    fi
  done < "$file"
}

print_code_block_list() {
  local file="$1"
  local limit="${2:-0}"
  local count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    count=$((count + 1))
    if (( limit > 0 && count > limit )); then
      break
    fi
    printf -- '- `%s`\n' "$line"
  done < "$file"
}

print_repo_list() {
  local limit="${1:-0}"
  local count=0
  while IFS='|' read -r path _remote branch dirty category; do
    [[ "$category" == "local-only" ]] || continue
    count=$((count + 1))
    if (( limit > 0 && count > limit )); then
      break
    fi
    printf -- '- `%s` branch `%s` dirty `%s`\n' "$path" "$branch" "$dirty"
  done < "$repo_scan_file"
}

emit_focus_section() {
  local limit="$1"
  case "$FOCUS" in
    repos)
      printf '## Local-Only Repos\n\n'
      [[ "$local_repo_count" -eq 0 ]] && printf -- '- none\n\n' || { print_repo_list "$limit"; printf '\n'; }
      ;;
    promote)
      printf '## Promote Next\n\n'
      [[ "$promote_count" -eq 0 ]] && printf -- '- none\n\n' || { print_split_list "$promote_file" "$limit"; printf '\n'; }
      ;;
    review)
      printf '## Review Later\n\n'
      [[ "$review_count" -eq 0 ]] && printf -- '- none\n\n' || { print_split_list "$review_file" "$limit"; printf '\n'; }
      ;;
    noise)
      printf '## Likely Noise\n\n'
      [[ "$noise_count" -eq 0 ]] && printf -- '- none\n\n' || { print_split_list "$noise_file" "$limit"; printf '\n'; }
      ;;
    secrets)
      printf '## Secret Risk Files\n\n'
      [[ "$secret_risk_count" -eq 0 ]] && printf -- '- none\n\n' || { print_code_block_list "$secret_risk_file" "$limit"; printf '\n'; }
      ;;
    uncovered)
      printf '## Uncovered Live Paths\n\n'
      [[ "$uncovered_count" -eq 0 ]] && printf -- '- none\n\n' || { print_split_list "$uncovered_file" "$limit"; printf '\n'; }
      ;;
  esac
}

while IFS= read -r managed; do
  [[ -n "$managed" ]] || continue
  [[ "$managed" =~ ^# ]] && continue
  printf '%s\n' "$managed" >> "$managed_paths_file"
done < "$INCLUDE_FILE"

find "$HOME_ROOT/.config" -maxdepth 1 -mindepth 1 | sort | while IFS= read -r abs; do
  rel="${abs#$HOME_ROOT/}"
  base="$(basename "$abs")"
  [[ "$base" == *-backup-back-up_* ]] && continue
  case "$base" in
    "Code - OSS"|discord|google-chrome|obsidian|dconf|pulse|evolution|cinnamon|cinnamon-session|nautilus|libreoffice|menus|Thunar|go)
      continue
      ;;
  esac
  printf '%s\n' "$rel" >> "$config_candidates_file"
done

find "$HOME_ROOT/.local/bin" -maxdepth 1 -type f | sort | while IFS= read -r abs; do
  printf '%s\n' "${abs#$HOME_ROOT/}" >> "$bin_candidates_file"
done

find "$HOME_ROOT/.local/share/applications" -maxdepth 1 -type f 2>/dev/null | sort | while IFS= read -r abs; do
  rel="${abs#$HOME_ROOT/}"
  base="$(basename "$abs")"
  case "$base" in
    mimeapps.list|mimeinfo.cache|userapp-Telegram\ Desktop-*.desktop)
      continue
      ;;
  esac
  printf '%s\n' "$rel" >> "$desktop_candidates_file"
done

find "$HOME_ROOT/__home_organized/scripts" -maxdepth 1 -type f 2>/dev/null | sort | while IFS= read -r abs; do
  printf '%s\n' "${abs#$HOME_ROOT/}" >> "$script_candidates_file"
done

for exact_path in \
  ".zshrc" \
  ".zprofile" \
  ".bashrc" \
  ".bash_profile" \
  ".profile" \
  ".gitconfig" \
  ".gtkrc-2.0" \
  ".dmrc" \
  "SYSTEM_DEBUG_START_HERE.md"
do
  [[ -e "$HOME_ROOT/$exact_path" ]] || continue
  printf '%s\n' "$exact_path" >> "$script_candidates_file"
done

find "$HOME_ROOT" -maxdepth 3 -name .git -type d 2>/dev/null | sort | while IFS= read -r gitdir; do
  repo_root="$(dirname "$gitdir")"
  is_system_repo_path "$repo_root" || continue
  remote="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
  if dirty_raw="$(git -C "$repo_root" status --porcelain 2>/dev/null)"; then
    if [[ -n "$dirty_raw" ]]; then
      dirty="$(awk 'END{print NR}' <<<"$dirty_raw")"
    else
      dirty="0"
    fi
  else
    dirty="error"
  fi
  if [[ "$remote" == git@github.com:goringich/* || "$remote" == https://github.com/goringich/* ]]; then
    category="personal"
  elif [[ -n "$remote" ]]; then
    category="external"
  else
    category="local-only"
  fi
  printf '%s|%s|%s|%s|%s\n' "$repo_root" "$remote" "${branch:-detached}" "$dirty" "$category" >> "$repo_scan_file"
done

for candidate_file in \
  "$config_candidates_file" \
  "$bin_candidates_file" \
  "$desktop_candidates_file" \
  "$script_candidates_file"
do
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    classify_candidate "$rel"
  done < "$candidate_file"
done

rg -l --hidden --no-messages --glob '!*.sqlite*' --glob '!*.db' --glob '!*.example.env' \
  '(github_pat_[A-Za-z0-9_]+|CODEX_GITHUB_PERSONAL_ACCESS_TOKEN|GITHUB_PERSONAL_ACCESS_TOKEN=)' \
  "$HOME_ROOT/.config/codex" \
  "$HOME_ROOT/.zsh_history" \
  "$HOME_ROOT/__home_organized/artifacts/zsh-history" \
  2>/dev/null | sort -u | while IFS= read -r path; do
    printf '%s\n' "${path#$HOME_ROOT/}" >> "$secret_risk_file"
  done

for file in \
  "$captured_file" \
  "$declared_missing_file" \
  "$uncovered_file" \
  "$external_only_file" \
  "$local_only_file" \
  "$secret_risk_file" \
  "$promote_file" \
  "$review_file" \
  "$noise_file"
do
  sort -u -o "$file" "$file"
done

personal_repo_count="$(awk -F'|' '$5=="personal"{count++} END{print count+0}' "$repo_scan_file")"
external_repo_count="$(awk -F'|' '$5=="external"{count++} END{print count+0}' "$repo_scan_file")"
local_repo_count="$(awk -F'|' '$5=="local-only"{count++} END{print count+0}' "$repo_scan_file")"
captured_count="$(wc -l < "$captured_file" | tr -d ' ')"
declared_missing_count="$(wc -l < "$declared_missing_file" | tr -d ' ')"
uncovered_count="$(wc -l < "$uncovered_file" | tr -d ' ')"
external_only_count="$(wc -l < "$external_only_file" | tr -d ' ')"
local_only_coverage_count="$(wc -l < "$local_only_file" | tr -d ' ')"
secret_risk_count="$(wc -l < "$secret_risk_file" | tr -d ' ')"
promote_count="$(wc -l < "$promote_file" | tr -d ' ')"
review_count="$(wc -l < "$review_file" | tr -d ' ')"
noise_count="$(wc -l < "$noise_file" | tr -d ' ')"

control_score=$((100 - local_repo_count * 15 - secret_risk_count * 3 - promote_count * 2 - declared_missing_count * 2))
(( control_score < 0 )) && control_score=0

if (( secret_risk_count > 0 || local_repo_count > 0 )); then
  control_lane="red"
elif (( promote_count > 0 || uncovered_count > 0 )); then
  control_lane="yellow"
else
  control_lane="green"
fi

display_limit=0
[[ "$MODE" == "compact" ]] && display_limit=12

{
  printf '# System Control Center\n\n'
  printf -- '- Mode: `%s`\n' "$MODE"
  printf -- '- Focus: `%s`\n' "$FOCUS"
  printf -- '- Repo scope: `%s`\n' "$SYSTEM_CONTROL_REPO_SCOPE"
  printf -- '- Generated: `%s`\n' "$(date -Is)"
  printf -- '- Bootstrap root: `%s`\n\n' "$BOOTSTRAP_ROOT"

  printf '## Control Score\n\n'
  printf -- '- score: `%s/100`\n' "$control_score"
  printf -- '- lane: `%s`\n' "$control_lane"
  printf -- '- runtime report: `%s`\n' "$LATEST_REPORT"
  printf -- '- tracked catalog: `%s`\n\n' "$DOC_OUT"

  printf '## Now\n\n'
  if (( secret_risk_count > 0 )); then
    printf -- '- rotate or relocate secrets first: `%s` risk files still contain token-like material\n' "$secret_risk_count"
  fi
  if (( local_repo_count > 0 )); then
    printf -- '- resolve `%s` local-only repos so they stop blocking true GitHub-backed restore\n' "$local_repo_count"
  fi
  if (( promote_count > 0 )); then
    printf -- '- decide which `%s` promote-candidate paths should become canonical payload next\n' "$promote_count"
  fi
  if (( review_count > 0 )); then
    printf -- '- review `%s` borderline paths before they drift further outside the system model\n' "$review_count"
  fi
  if (( secret_risk_count == 0 && local_repo_count == 0 && promote_count == 0 && review_count == 0 )); then
    printf -- '- no urgent control gaps detected\n'
  fi
  printf '\n'

  printf '## Summary\n\n'
  printf -- '- personal repos: `%s`\n' "$personal_repo_count"
  printf -- '- external repos: `%s`\n' "$external_repo_count"
  printf -- '- local-only repos: `%s`\n' "$local_repo_count"
  printf -- '- live paths captured in personal git: `%s`\n' "$captured_count"
  printf -- '- declared for snapshot but not captured yet: `%s`\n' "$declared_missing_count"
  printf -- '- uncovered live paths: `%s`\n' "$uncovered_count"
  printf -- '- promote next: `%s`\n' "$promote_count"
  printf -- '- review later: `%s`\n' "$review_count"
  printf -- '- likely noise: `%s`\n' "$noise_count"
  printf -- '- secret-risk files: `%s`\n\n' "$secret_risk_count"

  if [[ "$FOCUS" == "all" ]]; then
    printf '## Local-Only Repos\n\n'
    [[ "$local_repo_count" -eq 0 ]] && printf -- '- none\n' || print_repo_list "$display_limit"
    printf '\n'

    printf '## Promote Next\n\n'
    [[ "$promote_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$promote_file" "$display_limit"
    printf '\n'

    printf '## Review Later\n\n'
    [[ "$review_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$review_file" "$display_limit"
    printf '\n'

    printf '## Likely Noise\n\n'
    [[ "$noise_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$noise_file" "$display_limit"
    printf '\n'

    printf '## Secret Risk Files\n\n'
    [[ "$secret_risk_count" -eq 0 ]] && printf -- '- none\n' || print_code_block_list "$secret_risk_file" "$display_limit"
    printf '\n'
  else
    emit_focus_section "$display_limit"
  fi

  printf '## Declared But Not Yet Captured\n\n'
  [[ "$declared_missing_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$declared_missing_file" "$display_limit"
  printf '\n'

  if [[ "$MODE" == "full" ]]; then
    printf '## Captured In Personal Git\n\n'
    [[ "$captured_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$captured_file" 0
    printf '\n'

    printf '## External-Only Coverage\n\n'
    [[ "$external_only_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$external_only_file" 0
    printf '\n'

    printf '## Local-Only Repo Coverage\n\n'
    [[ "$local_only_coverage_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$local_only_file" 0
    printf '\n'
  fi
} > "$report_file"

ln -sfn "$report_file" "$LATEST_REPORT"
find "$LOG_ROOT" -maxdepth 1 -type f -name 'system-control-*.md' | sort -r | awk "NR>${MAX_LOGS}" | xargs -r rm -f

if [[ "$SYNC_DOCS" -eq 1 ]]; then
  if [[ -f "$BOOTSTRAP_ROOT/scripts/export-repo-inventory.sh" ]]; then
    SYSTEM_REPO_SCOPE="$SYSTEM_CONTROL_REPO_SCOPE" bash "$BOOTSTRAP_ROOT/scripts/export-repo-inventory.sh" >/dev/null
  fi
  doc_tmp="${tmp_dir}/system-control-catalog.md"
  {
    printf '# system-control-catalog\n\n'
    printf '## Control Score\n\n'
    printf -- '- score: `%s/100`\n' "$control_score"
    printf -- '- lane: `%s`\n\n' "$control_lane"

    printf '## Summary\n\n'
    printf -- '- personal repos: `%s`\n' "$personal_repo_count"
    printf -- '- external repos: `%s`\n' "$external_repo_count"
    printf -- '- local-only repos: `%s`\n' "$local_repo_count"
    printf -- '- declared but not captured: `%s`\n' "$declared_missing_count"
    printf -- '- uncovered live paths: `%s`\n' "$uncovered_count"
    printf -- '- promote next: `%s`\n' "$promote_count"
    printf -- '- review later: `%s`\n' "$review_count"
    printf -- '- likely noise: `%s`\n' "$noise_count"
    printf -- '- secret-risk files: `%s`\n\n' "$secret_risk_count"

    printf '## Local-Only Repos\n\n'
    [[ "$local_repo_count" -eq 0 ]] && printf -- '- none\n' || print_repo_list 0
    printf '\n'

    printf '## Promote Next\n\n'
    [[ "$promote_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$promote_file" 0
    printf '\n'

    printf '## Review Later\n\n'
    [[ "$review_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$review_file" 0
    printf '\n'

    printf '## Likely Noise\n\n'
    [[ "$noise_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$noise_file" 0
    printf '\n'

    printf '## Declared But Not Yet Captured\n\n'
    [[ "$declared_missing_count" -eq 0 ]] && printf -- '- none\n' || print_split_list "$declared_missing_file" 0
    printf '\n'

    printf '## Secret Risk Files\n\n'
    [[ "$secret_risk_count" -eq 0 ]] && printf -- '- none\n' || print_code_block_list "$secret_risk_file" 0
  } > "$doc_tmp"
  write_if_changed "$DOC_OUT" "$doc_tmp" || true
fi

printf 'system-control: report=%s score=%s lane=%s captured=%s declared_missing=%s promote=%s local_only_repos=%s secret_risk=%s\n' \
  "$LATEST_REPORT" \
  "$control_score" \
  "$control_lane" \
  "$captured_count" \
  "$declared_missing_count" \
  "$promote_count" \
  "$local_repo_count" \
  "$secret_risk_count"

cat "$report_file"
