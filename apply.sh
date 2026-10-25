#!/usr/bin/env bash
# apply.sh — restore one theme from this repo into $HOME.
# Reverse of backup.sh: the theme folder is the source, $HOME is the target.
# Usage: ./apply.sh [theme]   (defaults to "tokyonight")
# Run this on a fresh install after cloning the repo.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="${1:-tokyonight}"

# shellcheck source=components.sh
source "$REPO/components.sh"

if [[ ! -d "$REPO/$THEME" ]]; then
  echo "apply: theme folder not found: $REPO/$THEME" >&2
  exit 1
fi

apply_pair() { # apply_pair <repo path> <live path>
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then
    echo "skip: $src (not in this theme)"
    return
  fi

  echo "apply: $src -> $dst"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    rsync -a --delete --exclude=.git "$src/" "$dst/"
  else
    mkdir -p "$(dirname "$dst")"
    rsync -a "$src" "$dst"
  fi
}

for pair in "${PAIRS[@]}"; do
  apply_pair "$REPO/$THEME/${pair#*|}" "${pair%%|*}"
done

for pair in "${SHARED_PAIRS[@]}"; do
  apply_pair "$REPO/common/${pair#*|}" "${pair%%|*}"
done
