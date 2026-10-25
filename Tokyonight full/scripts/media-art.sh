#!/usr/bin/env bash
# media-art.sh <art url> — fetch a track's cover art once, print a local path.
#
# MPRIS hands the shell the art as an https URL (Spotify) or a local file (a
# browser's tab thumbnail). File or web, the shell's look for that art is
# black-and-white, so the file that lands in the cache is *already grey*:
# every view (the bar's square, the flyout's record) draws one greyscale file
# instead of each trusting a shader to do it. The same source hits the cache; a
# skipped track writes its own file and never clobbers the current one.
#
# Prints the cached path on success and nothing on failure — the caller has a
# drawn fallback disc, so a missing image is a look, not an error.
set -eu

# Only the web and local files. Any other scheme from a hostile MPRIS player
# must not turn this into an arbitrary reader.
case "$1" in
    http://*|https://*|file://*) ;;
    *) exit 0 ;;
esac

cache="${XDG_CACHE_HOME:-$HOME/.cache}/tokyonight/media-art"
mkdir -p "$cache"

# Keyed on the URL for the web (a CDN address is the art's stable name) and on
# the *content* for a local file, because a browser rewrites one art path as
# the track changes — keying that on the URL would serve the old cover forever.
case "$1" in
    file://*)
        local_path=${1#file://}
        [ -f "$local_path" ] || exit 0
        key=$(sha256sum "$local_path" | cut -d' ' -f1)
        ;;
    *)
        key=$(printf '%s' "$1" | sha256sum | cut -d' ' -f1)
        ;;
esac

ext=${1%%\?*}          # drop the query before taking the extension
ext=${ext##*.}
case "$ext" in
    jpg|jpeg|png|webp|gif|bmp) ;;
    *) ext=jpg ;;      # Spotify serves image/jpeg from extension-less URLs
esac
out="$cache/$key.$ext"
[ -s "$out" ] && { printf '%s\n' "$out"; exit 0; }

tmp="$out.$$.part"
trap 'rm -f "$tmp"' EXIT
# `--` ends options, so a URL beginning with `-` cannot be read as a flag.
# stderr is dropped: a fetch or convert failure (offline, a dead CDN, a
# hostile source that is not an image) is expected and the drawn fallback
# covers it, so it must not spam the shell's log.
case "$1" in
    file://*) cp "$local_path" "$tmp" ;;
    *) curl -fsSL --max-time 10 --retry 1 -o "$tmp" -- "$1" 2>/dev/null || exit 0 ;;
esac

# Greyscale here, once, so no view has to get the look right itself. A failed
# convert means the source is not renderable — print nothing, cache nothing.
if command -v magick >/dev/null 2>&1; then
    magick "$tmp" -colorspace Gray "$out" 2>/dev/null || exit 0
elif command -v convert >/dev/null 2>&1; then
    convert "$tmp" -colorspace Gray "$out" 2>/dev/null || exit 0
else
    mv "$tmp" "$out"  # no converter: hand the original over as-is
fi
[ -s "$out" ] && printf '%s\n' "$out"