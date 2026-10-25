#!/usr/bin/env bash
# tests/test-toast-icon-size.sh
#
# Regression test for the toast icon collapsing to a 1px speck.
#
# NotifyIcon.qml sized its Image with
#   width:  Math.min(size, Math.max(paintedWidth, 1))
# and paintedWidth is derived from the Image's own width, so the binding was
# circular and settled at 1x1 for every source. A grep cannot catch a binding
# loop, so this renders the real component offscreen, grabs each icon on a solid
# background, and trims the grab to the pixels actually drawn.
#
# Requirements: quickshell and ImageMagick. Skips (exit 0) if either is absent.
#
# Expectations at a 40px box:
#   nordvpn.svg (512x512) -> fit to 40        (a 1px collapse fails this)
#   cachy-*.svg (24x24)   -> natural 24, never upscaled
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

OUT=${TOAST_ICON_PROBE_DIR:-/tmp/opencode/toast-icon-probe}
PROBE="$PWD/tests/toast-icon-probe.qml"

command -v quickshell >/dev/null || { echo "skip: quickshell not installed"; exit 0; }
if ! command -v convert >/dev/null && ! command -v magick >/dev/null; then
    echo "skip: ImageMagick not installed"
    exit 0
fi

rm -rf "$OUT"
mkdir -p "$OUT"

QT_QPA_PLATFORM=offscreen TOAST_ICON_REPO="$PWD" timeout 30 quickshell -p "$PROBE" >"$OUT/run.log" 2>&1
rc=$?

if [ ! -s "$OUT/nordvpn.png" ] || [ ! -s "$OUT/cachy.png" ]; then
    echo "FAIL probe produced no grabs (quickshell rc=$rc)"
    sed 's/^/     /' "$OUT/run.log" | tail -20
    exit 1
fi

# Trim the solid background and report the drawn icon's bounding box as WxH.
measure() {
    convert "$1" -fuzz 5% -trim -format '%wx%h' info: 2>/dev/null
}

fail=0
check_size() { # check_size <name> <png> <min> <max>
    local name=$1 png=$2 min=$3 max=$4 box w h
    box=$(measure "$png")
    w=${box%x*}
    h=${box#*x}
    if [ -n "$w" ] && [ -n "$h" ] && [ "$w" -ge "$min" ] && [ "$w" -le "$max" ] \
       && [ "$h" -ge "$min" ] && [ "$h" -le "$max" ]; then
        echo "ok   $name drawn at ${w}x${h} (want ${min}-${max})"
    else
        echo "FAIL $name drawn at ${box:-none} (want ${min}-${max})"
        fail=1
    fi
}

# nordvpn.svg is 512x512: fit to the 40px box.
check_size nordvpn "$OUT/nordvpn.png" 36 44
# cachy-*.svg is a 24px canvas whose ink fills only 20x18 (transparent padding),
# so the drawn box is ~20x18. Upscaled to 40 it would be ~33x30: assert well
# above the 1px collapse and well below an upscale.
check_size cachy   "$OUT/cachy.png"   15 28

exit $fail
