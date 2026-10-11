#!/usr/bin/env bash
# media-art.sh <url> — fetch a track's cover art once, print a local path.
#
# MPRIS hands the shell an https URL for the art (Spotify always; browsers
# usually nothing). Pointing an Image straight at that URL would re-download it
# on every reload and blank the record the moment the network hiccups, so the
# download happens here, once, and lands in a cache keyed by the URL itself.
# The same URL hits the cache; a skipped track writes its own file and never
# clobbers the current one.
#
# Prints the path on success and nothing on failure — the caller has a drawn
# fallback record, so a missing image is a look, not an error.
set -eu

# Only the web. A file:// or other scheme from a hostile MPRIS player must not
# turn this into an arbitrary local-file reader.
case "$1" in
    http://*|https://*) ;;
    *) exit 0 ;;
esac
url=$1

cache="${XDG_CACHE_HOME:-$HOME/.cache}/tokyonight/media-art"
mkdir -p "$cache"

key=$(printf '%s' "$url" | sha256sum | cut -d' ' -f1)
ext=${url%%\?*}          # drop the query before taking the extension
ext=${ext##*.}
case "$ext" in
    jpg|jpeg|png|webp|gif|bmp) ;;
    *) ext=jpg ;;        # Spotify serves image/jpeg from extension-less URLs
esac
out="$cache/$key.$ext"
[ -s "$out" ] && { printf '%s\n' "$out"; exit 0; }

tmp="$out.$$.part"
trap 'rm -f "$tmp"' EXIT
# `--` ends options, so a URL beginning with `-` cannot be read as a flag.
# stderr is dropped: a fetch that fails (offline, a dead CDN) is expected and
# the drawn fallback covers it, so it must not spam the shell's log.
if curl -fsSL --max-time 10 --retry 1 -o "$tmp" -- "$url" 2>/dev/null; then
    mv "$tmp" "$out"
    printf '%s\n' "$out"
fi
