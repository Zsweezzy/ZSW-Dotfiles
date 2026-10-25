#!/usr/bin/env bash
# Instant screenshot of the focused monitor — the old `grim -o` behavior.
# Called from Print in hyprland.lua.
#
# Not HyprCapture's quick(): that path still runs its Qt helper, which builds a
# layer-shell overlay window and maps it for ~50-150 ms on every press (measured
# with hyprctl layers; upstream master's src/ui/main.cpp passes `quick` into the
# overlay and merely swaps the wait for a zero-delay finishCapture). grim has no
# helper process, so nothing appears on screen at all.
# Shift+Print (region) keeps using HyprCapture, which needs its overlay anyway.

set -euo pipefail

dir="$HOME/Pictures/Screenshots" # same path as plugin.hyprcapture.save_dir
out="$dir/Screenshot-$(date +%Y-%m-%d-%H%M%S).png"
mkdir -p "$dir"

# Two presses inside the same second would overwrite the first file.
[ -e "$out" ] && out="${out%.png}-$RANDOM.png"

grim -o "$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')" "$out"
wl-copy --type image/png <"$out"
notify-send -a screenshot "Screenshot saved" "$(basename "$out")"
