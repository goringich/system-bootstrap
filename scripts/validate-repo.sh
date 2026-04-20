#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Checking shell syntax"
while IFS= read -r file; do
  bash -n "$file"
done < <(find bin scripts -type f \( -name '*.sh' -o -perm -111 \) | sort)

echo "==> Checking required manifests"
required_files=(
  configs/repos.txt
  configs/repos-all.txt
  configs/repos-minimal.txt
  configs/repo-inventory-excludes.txt
  configs/local-only-repos.txt
  configs/system-paths.txt
  configs/rsync-excludes.txt
  scripts/include-paths.txt
)

for file in "${required_files[@]}"; do
  [[ -s "$file" ]] || {
    echo "missing or empty required file: $file" >&2
    exit 1
  }
done

echo "==> Checking repo manifest format"
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  [[ "$line" =~ ^# ]] && continue
  fields="$(awk -F'|' '{print NF}' <<<"$line")"
  [[ "$fields" -eq 4 ]] || {
    echo "invalid repo manifest line: $line" >&2
    exit 1
  }
done < configs/repos-all.txt

echo "==> Checking tracked files for obvious secret material"
secret_pattern='(ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY)'
if git grep -nIE "$secret_pattern" -- . ':!scripts/validate-repo.sh'; then
  echo "secret-like material found in tracked files" >&2
  exit 1
fi

echo "==> Checking dry-run entrypoint"
bash bin/restore-my-system --profile minimal --dry-run --skip-repos --skip-packages --skip-aur --skip-services --skip-configs --skip-system-overlay >/tmp/system-bootstrap-validate-dry-run.log

echo "validation ok"
