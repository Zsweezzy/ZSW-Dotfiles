#!/bin/bash
# openapps-focus.sh — cycle focus to the next open application class.
# Called from waybar's custom/openapps on-click / scroll. Each invocation
# focuses the *next* class in hyprctl clients order (same order as the
# glyphs), wrapping around — so clicking repeatedly reaches every app.
clients=$(hyprctl clients -j 2>/dev/null)

# Ordered, deduped class list (matches openapps.sh glyph order)
classes=$(jq -r '.[].class // empty' <<<"$clients" | awk '!seen[$0]++' | grep .)
[ -z "$classes" ] && exit 0

# Currently focused class
current=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')

next=""
prev=""
seen_cur=0
for c in $classes; do
    if [ "$c" = "$current" ]; then
        seen_cur=1
        continue
    fi
    if [ "$seen_cur" = "1" ]; then
        next="$c"
        break
    fi
    prev="$c"
done
# Wrap: nothing after current → first, nothing before current → last
[ -z "$next" ] && next=$(printf '%s\n' "$classes" | head -1)
[ -z "$prev" ] && prev=$(printf '%s\n' "$classes" | tail -1)

# dir from argv: "next" (default) or "prev"
target="$next"
[ "$1" = "prev" ] && target="$prev"

# Focus the first window of that class
hyprctl dispatch "hl.dsp.focus({ window = \"class:${target}\" })" >/dev/null 2>&1