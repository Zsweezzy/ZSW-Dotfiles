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

for pair in "${PAIRS[@]}"; do
  dst="${pair%%|*}"
  rel="${pair#*|}"
  src="$REPO/$THEME/$rel"

  if [[ ! -e "$src" ]]; then
    echo "skip: $src (not in this theme)"
    continue
  fi

  echo "apply: $src -> $dst"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    rsync -a --delete "$src/" "$dst/"
  else
    mkdir -p "$(dirname "$dst")"
    rsync -a "$src" "$dst"
  fi
done
