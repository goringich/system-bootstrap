#!/usr/bin/env bash
set -euo pipefail

roots=("$HOME/.config/hypr/scripts" "$HOME/.config/hypr/UserScripts")
entries=()

for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r file; do
    base="$(basename "$file")"
    rel="${file#$HOME/}"
    entries+=("$base :: $rel")
  done < <(find "$root" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | sort)
done

if [[ "${#entries[@]}" -eq 0 ]]; then
  echo "No user scripts found."
  exit 0
fi

while true; do
  clear
  printf "SCRIPT HUB\n\n"
  choice=$(printf '%s\n' "${entries[@]}" | fzf --height=70% --layout=reverse --border --prompt="scripts> " --ansi) || exit 0
  script_rel="${choice#* :: }"
  script="$HOME/$script_rel"
  clear
  printf "Running: %s\n\n" "$script"
  case "$script" in
    *.py) python3 "$script" ;;
    *) bash "$script" ;;
  esac
  printf "\nPress Enter to return to the hub..."
  read -r _
done

