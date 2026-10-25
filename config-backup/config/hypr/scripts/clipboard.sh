#!/usr/bin/env bash
# clipboard.sh
# Clipboard history picker, bound to SUPER + V in hyprland.lua.
#
# cliphist owns the history (its two wl-paste watchers run at login); rofi only
# picks from it. Picking an entry decodes it back to the clipboard with wl-copy,
# so it is ready to paste with Ctrl+V.
#
# Image entries are shown with a thumbnail. rofi's dmenu mode renders an icon for
# a row when that row carries "<text>\0icon\x1f<path>": the NUL ends the visible
# text and 0x1f separates the "icon" marker from the path. Only rows whose
# cliphist preview says "binary data" (cliphist's marker for a non-text entry)
# get one, so text rows are unchanged.
#
# The script owns the rofi command line for the same reason the launcher bind does:
# Hyprland's exec does not keep a multi-word argument intact.

set -u

MONITOR="DP-1"          # main centre monitor, matching the launcher bind
THUMB_PX=48             # thumbnail / row icon size; raise for bigger previews
THUMB_DIR="${XDG_RUNTIME_DIR:-/tmp}/cliphist-thumbs"   # per boot; ids survive reboots, thumbs need not
# shortcut: cache key is the cliphist id (never reused while the db lives), so a
# wiped/rebuilt db could pair an id with a stale thumb; key by content if that matters
mkdir -p "$THUMB_DIR"

# cliphist list is newest-first and prints "<id>\t<preview>".
selection=$(
  cliphist list | while IFS=$'\t' read -r id preview; do
    if [[ $preview == *"binary data"* ]]; then
      thumb="$THUMB_DIR/$id.png"
      if [[ ! -s $thumb ]]; then
        rm -f "$thumb"
        cliphist decode "$id" 2>/dev/null \
          | magick - -thumbnail "${THUMB_PX}x${THUMB_PX}" PNG:"$thumb" 2>/dev/null || rm -f "$thumb"
      fi
      if [[ -s $thumb ]]; then
        printf '%s\t%s\000icon\037%s\n' "$id" "$preview" "$thumb"
        continue
      fi
    fi
    printf '%s\t%s\n' "$id" "$preview"
  done | rofi -dmenu -i -monitor "$MONITOR" -p clipboard \
      -theme-str "element-icon { size: ${THUMB_PX}px; }"
)

# rofi prints the chosen row, or nothing on Escape.
[[ -z $selection ]] && exit 0
# The id is everything before the first TAB; the preview may itself contain tabs.
cliphist decode "${selection%%$'\t'*}" | wl-copy
