#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPL="$BASE/pkglist-explicit.txt"
AUR="$BASE/aurlist.txt"
FLAT="$BASE/flatpaks.txt"

if [[ ! -f "$EXPL" ]]; then echo "missing $EXPL"; exit 1; fi

echo "pkglist-explicit: $(wc -l < "$EXPL")"
echo "aurlist: $(wc -l < "$AUR")"
echo "flatpaks: $(wc -l < "$FLAT")"

if $DRY_RUN; then
  echo "(dry-run) Would install pacman packages from pkglist-explicit.txt"
  echo "(dry-run) Would install AUR packages from aurlist.txt via your AUR helper"
  echo "(dry-run) Would install flatpak apps from flatpaks.txt"
  exit 0
fi

echo "Installing pacman packages..."
sudo pacman -S --needed - < "$EXPL"

echo "AUR: install via your helper (paru/yay/etc)."
echo "  example: paru -S --needed - < $AUR"
echo "Flatpak: flatpak install --noninteractive $(paste -sd' ' "$FLAT")"

# Nix apps need the /run/opengl-driver glue (see src/gpu/); without it they
# render in software. Safe to re-run any time.
echo "Installing GPU glue for Nix apps..."
sudo bash "$BASE/../src/gpu/install.sh"

echo "restore.sh: ready."
echo "Next: cd ~/nix && nix run home-manager -- switch --flake .#maxii"
