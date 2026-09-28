#!/usr/bin/env bash
# icon-resolve.sh — resolve an icon name or file path to an actual image file.
# Usage: icon-resolve.sh <name|path> [size]
# Prints the first matching file (png/svg/svgz/xpm), or nothing if none found.
#
# QtQuick's Image can't look up freedesktop icon-theme names, and SNI items
# only hand us a name (item.icon); this script bridges the gap for TrayIcon
# (the tray in Tray.qml). Prefers exact-size dirs, then scalable, then any.
#
# Also tries the last dotted segment (org.kde.kate -> kate) since window
# classes often carry a reverse-DNS prefix while theme icons use the app name.

name="${1:-}"
size="${2:-18}"
[ -z "$name" ] && exit 0

# already an existing file path?
if [ -f "$name" ]; then
    printf '%s' "$name"
    exit 0
fi

# strip any directory from the name (theme names carry no extension here —
# existing-file paths were already handled above)
base="${name##*/}"

bases=("$base")
tail="${base##*.}"
[ "$tail" != "$base" ] && bases+=("$tail")

roots=()
for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/pixmaps; do
    [ -d "$d" ] && roots+=("$d")
done
for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    [ -d "$d/icons" ] && roots+=("$d/icons")
done

# pass 1: exact size (or its @2x/@3x) and scalable dirs,
# pass 2: any file with that basename anywhere under an icon root
for b in "${bases[@]}"; do
    for pattern in \
        ".*/(${size}x${size}|${size}@[0-9]+x|scalable)/[^/]*${b}\.(png|svg|svgz|xpm)" \
        ".*/[^/]*${b}\.(png|svg|svgz|xpm)"; do
        for root in "${roots[@]}"; do
            hit=$(find -L "$root" -regextype posix-extended -maxdepth 6 -iregex "$pattern" -print -quit 2>/dev/null)
            if [ -n "$hit" ]; then
                printf '%s' "$hit"
                exit 0
            fi
        done
    done
done

exit 0