#!/usr/bin/env bash
# backup.sh — sync theme dotfiles into ZSW-Dotfiles, then commit & push.
# Every theme lives in its own folder at the repo root, split into named
# *component* folders (the app/system owning the config). The component
# folder itself is the app folder, e.g.
#   ~/.config/kitty/kitty.conf      -> tokyonight/kitty/kitty.conf
#   ~/.local/share/plasma/desktoptheme -> tokyonight/plasma/desktoptheme
#   ~/.local/share/wallpapers       -> tokyonight/wallpapers
# Usage: ./backup.sh [theme]   (defaults to "tokyonight"; e.g. ./backup.sh nord)
# Run me after you tweak a theme; safe to run repeatedly.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

THEME="${1:-tokyonight}"

# shellcheck source=components.sh
source "$REPO/components.sh"

sync_pair() { # sync_pair <live path> <repo path>
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then
    echo "skip: $src (doesn't exist)"
    return
  fi
  echo "sync: $src -> $dst"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    rsync -a --delete --exclude=.git "$src/" "$dst/"
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    if [[ -d "$dst" ]]; then
      echo "  note: removing stale directory at $dst"
      rm -rf "$dst"
    fi
    rsync -a "$src" "$dst"
  else
    echo "skip: $src (not a regular file or dir)"
  fi
}

for pair in "${PAIRS[@]}"; do
  sync_pair "${pair%%|*}" "$THEME/${pair#*|}"
done

for pair in "${SHARED_PAIRS[@]}"; do
  sync_pair "${pair%%|*}" "common/${pair#*|}"
done

git add -A
if git diff --cached --quiet; then
  echo "Nothing to commit — repo up to date."
else
  git commit -m "Backup theme configs ($(date +%Y-%m-%d))"
  git push
  echo "Pushed to origin/main."
fi