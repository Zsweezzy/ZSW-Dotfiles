#!/usr/bin/env bash
# Region screenshot using grim + slurp
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
out="$dir/Screenshot-$(date +%Y-%m-%d-%H%M%S).png"
mkdir -p "$dir"
[ -e "$out" ] && out="${out%.png}-$RANDOM.png"

region=$(slurp)
[ -z "$region" ] && exit 0

grim -g "$region" "$out"
wl-copy --type image/png <"$out"
notify-send -a screenshot "Screenshot saved" "$(basename "$out")"
