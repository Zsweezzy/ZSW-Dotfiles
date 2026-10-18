#!/bin/bash
# test-wifi-glyph.sh — the signal tier -> wifi glyph mapping, checked as code.
#
# The four glyphs live in Settings.qml as \u{...} escapes, so a wrong tier or
# an off-by-one index draws an empty box on the bar and on every network row —
# nothing else in the suite can see that, and no script is involved. The test
# takes the functions and properties straight out of Settings.qml (the same
# source-extraction the forget-button probe uses) and evaluates them offscreen,
# so it cannot drift from what the bar runs.
#
# Exit codes: 0 all cases map, 10+n a case n disagreed, 20 source missing.
# Needs qml6 (qt6-declarative tools); it is the only QML runtime that can be
# asked for an exit code without a window.
cd "$(dirname "$0")/.." || exit 1
probe=$(mktemp -d /tmp/opencode-glyph.XXXXXX)
trap 'rm -rf "$probe"' EXIT

python3 - "$probe/probe.qml" <<'PY' || exit 20
import re, sys
src = open("Settings.qml", encoding="utf-8").read()

def block(pattern, what):
    m = re.search(pattern, src, re.S)
    if not m:
        print(f"Settings.qml: cannot find {what} — the mapping moved?", file=sys.stderr)
        sys.exit(1)
    return m.group(0)

parts = [
    block(r"    function bars\(signal\) \{.*?\n    \}\n", "bars()"),
    block(r"    readonly property var wifiGlyphs: [^\n]*\n", "wifiGlyphs"),
    block(r"    function signalGlyph\(tier\) \{.*?\n    \}\n", "signalGlyph()"),
    block(r'    readonly property string wifiGlyph: .*?root\.signalGlyph\(root\.bars\(root\.wifiSignal\)\)',
          "wifiGlyph"),
]
# wifiSignal reads the monitor's adapters; the probe sets it directly, because
# this is about the mapping, not about finding the adapter.
open(sys.argv[1], "w", encoding="utf-8").write(
    "import QtQuick\n"
    "Item {\n"
    "    id: root\n"
    "    property int wifiSignal: 0\n"
    + "".join(parts) + """
    // One case per tier plus the no-reading fallback. Qt.exit is the channel:
    // this runtime swallows print/console, and a wrong code names the case.
    Component.onCompleted: {
        const cases = [
            [95, "\\u{f0928}"], [70, "\\u{f0925}"],
            [50, "\\u{f0922}"], [10, "\\u{f091f}"],
            [-1, "\\uf1eb"], [80, "\\u{f0928}"], [60, "\\u{f0925}"], [35, "\\u{f0922}"],
        ]
        for (let i = 0; i < cases.length; i++) {
            root.wifiSignal = cases[i][0]
            if (root.wifiGlyph !== cases[i][1])
                Qt.exit(10 + i)
        }
        Qt.exit(0)
    }
}
""")
PY

command -v qml6 >/dev/null || { printf '  FAIL wifi glyph: qml6 not found (qt6-declarative tools)\n' >&2; exit 1; }
timeout 20 env QT_QPA_PLATFORM=offscreen qml6 "$probe/probe.qml"
rc=$?
case $rc in
    0)  printf '  ok   wifi glyph: every signal tier maps to its glyph\n' >&2 ;;
    124) printf '  FAIL wifi glyph: probe timed out\n' >&2
        exit 1 ;;
    20) printf '  FAIL wifi glyph: Settings.qml no longer has the mapping blocks\n' >&2
        exit 1 ;;
    *)  printf '  FAIL wifi glyph: case %s mapped to the wrong glyph (exit %s)\n' \
            "$((rc - 10))" "$rc" >&2
        exit 1 ;;
esac
