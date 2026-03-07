#!/usr/bin/env bash
set -euo pipefail

if ! command -v sudo >/dev/null 2>&1; then
  echo "This script requires sudo to install packages" >&2
  exit 1
fi

# Prefer pacman; fallback hints for yay
if command -v pacman >/dev/null 2>&1; then
  echo "> Installing: duf eza bat ripgrep fd dust"
  sudo pacman -S --needed --noconfirm duf eza bat ripgrep fd dust || {
    echo "Some packages failed. On AUR-based systems you may use yay (e.g., eza might be eza-git)." >&2
  }
else
  cat >&2 <<'EOF'
Pacman not found. If you use an AUR helper:
  yay -S duf eza bat ripgrep fd dust
EOF
fi
