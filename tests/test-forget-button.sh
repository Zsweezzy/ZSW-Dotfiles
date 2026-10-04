#!/bin/bash
# test-forget-button.sh — the paired-row forget × in the bluetooth panel.
#
# DeviceRow is shared: the wifi list, the "Find new devices" button and the
# bluetooth device list are all the same component. So the × has to be opt-in,
# and the part that can rot silently is the layout — a forget button that
# measures width 0 or visible:false paints nothing and still looks "fine" in
# review, which is the toast and clock failure mode in this tree.
#
# Three layers, cheapest first:
#   1. static — the opt-in defaults off, only the bluetooth delegate sets it,
#      the × outranks the whole-row click area and does not toggle, and
#      Settings.qml actually runs `bt-dev.sh forget`
#   2. probe  — an offscreen render of the REAL DeviceRow, extracted from
#      SettingsFlyout.qml at run time (never a copy, so it cannot drift) reports
#      its geometry, and Qt's own hit test says who gets a click in the
#      right-hand slot
#   3. A/B    — the same row measured out of `git show HEAD:SettingsFlyout.qml`,
#      so "the wifi rows did not move" is a number and not a promise
#
# Run from anywhere: cd "$(dirname "$0")/.." first.
cd "$(dirname "$0")" || exit 1
cd .. || exit 1
fail=0
ok()   { printf '  ok   %s\n' "$1" >&2; }
bad()  { printf '  FAIL %s\n' "$1" >&2; fail=1; }

echo "forget button:"

# ---------- 1. structure ----------
python3 - <<'PY' || fail=1
import re, sys

def code(text):
    """Comments stripped. A check for `dr.clicked()` must be satisfied by code
    and must not be broken by the prose warning against it — and brace matching
    is safer without them too."""
    return re.sub(r"//[^\n]*", "", text)

src = code(open("SettingsFlyout.qml").read())
pill = code(open("Settings.qml").read())

def block(text, start):
    """The text of the {…} that starts at or after `start`."""
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[start:j + 1]
    raise SystemExit("unbalanced braces")

def enclosing(text, marker):
    """The {…} whose header `marker` sits inside — `id:` names come after
    their object's opening brace, so this cannot use block()."""
    i = text.rindex("{", 0, text.index(marker))
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    raise SystemExit("unbalanced braces")

def need(cond, msg):
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        sys.exit(1)

comp = block(src, src.index("component DeviceRow: Item"))
# every `DeviceRow {` that is not the component declaration. One call site is
# written `delegate: DeviceRow {`, so this cannot key on the line start.
sites = [block(src, m.start()) for m in re.finditer(r"DeviceRow \{", src)
         if not src[:m.start()].endswith("component ")]
need(len(sites) == 3, "DeviceRow has 3 call sites: wifi, scan button, bt list")
wifi = next(s for s in sites if "ssid" in s)
scan = next(s for s in sites if "Find new devices" in s)
bt = next(s for s in sites if "modelData.paired" in s)

# the opt-in itself
need("property bool forgetable: false" in comp,
     "forget is opt-in: forgetable defaults to false")
need("signal forgotten()" in comp,
     "DeviceRow signals forgotten() rather than reaching for the pill itself")

# the risk the ticket calls out: the whole-row MouseArea is declared last in
# the base component, so the × has to out-rank it in BOTH declaration order and
# z — with the hover area on top the click forgets nothing and toggles instead.
need(comp.index("id: forgetHit") > comp.index("id: hover"),
     "the × is declared after the whole-row click area")
hit = enclosing(comp, "id: forgetHit")
need('objectName: "forgetHit"' in hit,
     "the × names its own hit plate so it can be found from a test")
z = re.search(r"(?m)^\s*z:\s*(-?\d+)", hit)
need(z is not None and int(z.group(1)) > 0,
     "the × carries an explicit z above the whole-row click area (z: %s)"
     % (z.group(1) if z else "none"))
need("dr.forgotten()" in hit and "dr.clicked()" not in hit,
     "clicking the × forgets only — it never fires the row toggle")

# the reveal condition, and that it replaces the word rather than joining it
need(re.search(r"property bool forgetShown:\s*dr\.forgetable", comp) is not None,
     "the × only exists on a row that asked for it and is hovered")
word = enclosing(comp, "id: stateText")
need(re.search(r"(?m)^\s*visible:.*forgetShown", word) is not None,
     "the status word hides while the × is shown (one slot, one piece of state)")

# the call sites
need("forgetable" not in wifi and "forgotten" not in wifi,
     "wifi rows are untouched: no forget affordance")
need("forgetable" not in scan and "forgotten" not in scan,
     "the scan button is untouched: no forget affordance")
need("forgetable: modelData.paired" in bt,
     "only PAIRED bluetooth rows opt in — a NEW row cannot forget")
need("onForgotten:" in bt and "forgetDevice(modelData.mac)" in bt,
     "the × calls forgetDevice for that device's own mac")

# the script side
fn = block(pill, pill.index("function forgetDevice"))
need('"forget"' in fn and "mac" in fn,
     "forgetDevice runs bt-dev.sh forget <mac>")
need("confirm.start()" in fn,
     "forgetDevice starts the confirming poll, so the row leaves the list")
PY

# ---------- 2 + 3. the real component, rendered ----------
if ! command -v quickshell >/dev/null; then
    echo "skip probe (no quickshell)"
    exit $fail
fi

probe=$(mktemp -d)
# Tokyo is a pragma Singleton, so it resolves from the probe's own directory.
ln -sf "$PWD/Tokyo.qml" "$probe/"

python3 - "$probe" <<'PY' || fail=1
import sys

def code(text):
    return __import__("re").sub(r"//[^\n]*", "", text)

out = sys.argv[1]

def block(text, start):
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[start:j + 1]
    raise SystemExit("unbalanced braces")

import subprocess
comp_new = block(code(open("SettingsFlyout.qml").read()),
                 code(open("SettingsFlyout.qml").read()).index("component DeviceRow: Item"))
base = subprocess.run(["git", "show", "HEAD:SettingsFlyout.qml"],
                      capture_output=True, text=True, check=True).stdout
comp_base = block(code(base), code(base).index("component DeviceRow: Item"))

# Deliberately not an f-string: QML is mostly braces.
HEAD = """import QtQuick
import QtQuick.Shapes
import Quickshell

// GENERATED by tests/test-forget-button.sh — do not edit.
// The component below is cut out of the real SettingsFlyout.qml at run time, so
// what is measured here is what ships, not a transcription of it.
ShellRoot {
%s

%s
    Item {
        width: 200
        height: 26
%s
    }

    // Which subtree owns the click at the right-hand slot. childAt walks down
    // too, so this resolves the × glyph as well as the button behind it.
    function ownerOf(it) {
        while (it) {
            if (it.objectName === "forgetHit") return "forget"
            it = it.parent
        }
        return "other"
    }
    function measure(r, label) {
        var byText = function (t) {
            return r.children.filter(function (k) { return k.text === t })
        }
        var f = r.children.filter(function (k) {
            return k.objectName === "forgetHit"
        })[0]
        var w = byText(r.status)[0]
        var hit = r.childAt(r.width - 8, r.height / 2)
        var r1 = function (n) { return Math.round(n * 10) / 10 }
        return "forgetprobe " + label + " "
            + JSON.stringify({
                forgetW: f === undefined ? -1 : r1(f.width),
                forgetH: f === undefined ? -1 : r1(f.height),
                forgetVisible: f === undefined ? "absent" : String(f.visible),
                wordVisible: w === undefined ? "absent" : String(w.visible),
                nameW: byText(r.name)[0] === undefined ? -1 : r1(byText(r.name)[0].width),
                hitOwner: hit === null ? "none" : ownerOf(hit)
            })
    }
    Timer {
        running: true
        interval: 80
        onTriggered: {
%s
            Qt.exit(0)
        }
    }
}
"""

def rows(body):
    """`body` is indented to sit inside the Item above."""
    return "\n".join(body)

new_rows = rows([
    '        DeviceRow {',
    '            id: pairedOff',
    '            width: 200; height: 26',
    '            name: "Studio Headset"; status: "PAIRED"',
    '            forgetable: true',
    '        }',
    '        DeviceRow {',
    '            id: pairedOn',
    '            width: 200; height: 26',
    '            name: "Studio Headset"; status: "PAIRED"',
    '            forgetable: true',
    '            hovered: true',
    '        }',
    '        // the wifi shape: forget never mentioned',
    '        DeviceRow {',
    '            id: wifiRow',
    '            width: 200; height: 26',
    '            name: "Studio Headset"; status: "PAIRED"',
    '        }',
    '        // a discovered-only bluetooth row',
    '        DeviceRow {',
    '            id: unpaired',
    '            width: 200; height: 26',
    '            name: "AirPods"; status: "NEW"',
    '        }',
    '        // the scan button, mid-scan',
    '        DeviceRow {',
    '            id: scanning',
    '            width: 200; height: 26',
    '            name: "Find new devices"; status: ""',
    '            busy: true',
    '        }',
])
new_prints = "\n".join([
    '            print(measure(pairedOff, "pairedOff"))',
    '            print(measure(pairedOn, "pairedOn"))',
    '            print(measure(wifiRow, "wifiRow"))',
    '            print(measure(unpaired, "unpaired"))',
    '            print(measure(scanning, "scanning"))',
])
open(out + "/probe.qml", "w").write(HEAD % (comp_new, "", new_rows, new_prints))

# The A/B half: the same row out of HEAD, with only the properties it had then.
base_rows = rows([
    '        DeviceRow {',
    '            id: baseWifi',
    '            width: 200; height: 26',
    '            name: "Studio Headset"; status: "PAIRED"',
    '        }',
])
base_prints = '            print(measure(baseWifi, "baseWifi"))'
open(out + "/baseprobe.qml", "w").write(
    HEAD % (comp_base, "", base_rows, base_prints))
PY

# quickshell prefixes every line (` DEBUG qml: forgetprobe …`), so match the
# payload rather than the line start.
run() { timeout 25 env QT_QPA_PLATFORM=offscreen quickshell -p "$probe/$1" 2>&1 \
        | sed 's/\x1b\[[0-9;]*m//g' | grep -o 'forgetprobe .*' ; }

got=$(run probe.qml) || true
base=$(run baseprobe.qml) || true
rm -rf "$probe"

if [ -z "$got" ] || [ -z "$base" ]; then
    bad "probe produced no measurements (probe harness broken, not the feature)"
    echo "forget button tests FAILED"
    exit 1
fi
echo "$got" >&2
echo "$base" >&2

python3 - "$got" "$base" <<'PY' || fail=1
import json, sys

def parse(blob):
    out = {}
    for line in blob.splitlines():
        label, payload = line.split(" ", 2)[1], line.split(" ", 2)[2]
        out[label] = json.loads(payload)
    return out

m = parse(sys.argv[1])
base = parse(sys.argv[2])["baseWifi"]
fails = []

def need(cond, msg):
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        fails.append(msg)

# 1. hovering a paired row shows the × in the right-hand slot
p = m["pairedOn"]
need(p["forgetVisible"] == "true" and p["forgetW"] >= 12,
     "hovering a paired row shows the × (%s x %s)"
     % (p["forgetW"], p["forgetH"]))
need(p["wordVisible"] == "false",
     "the × replaces the PAIRED/CONNECTED word, it does not sit beside it")
need(p["nameW"] == m["pairedOff"]["nameW"],
     "the row's name does not reflow when the × replaces the word (%s)"
     % p["nameW"])
# the × outranks the whole-row click area, so the toggle cannot also fire
need(p["hitOwner"] == "forget",
     "the × owns the click in the right-hand slot (toggle cannot eat it)")

# 2. every other shape is untouched. The × keeps its 20x20 geometry when
# hidden — that width IS the click target, so collapsing it to 0 would be the
# bug, not the fix. What must be true is that it is not visible (paints
# nothing) and not in the hit test (cannot steal the row's click).
for label, why in (("pairedOff", "a paired row not hovered"),
                   ("wifiRow", "a wifi row"),
                   ("unpaired", "a NEW, unpaired bluetooth row"),
                   ("scanning", "the scan button")):
    r = m[label]
    need(r["forgetVisible"] == "false",
         "no × at all on %s (visible %s)" % (why, r["forgetVisible"]))
    need(r["hitOwner"] == "other",
         "the row's own click area still owns the right slot on %s" % why)

# the wifi row did not move: same name width as it had before this change
need(m["wifiRow"]["nameW"] == base["nameW"],
     "wifi rows render exactly as they did at HEAD (%s vs %s)"
     % (m["wifiRow"]["nameW"], base["nameW"]))
need(base["forgetW"] == -1 and m["wifiRow"]["wordVisible"] == base["wordVisible"],
     "the wifi row's status word is still drawn, as at HEAD")

sys.exit(1 if fails else 0)
PY

[ $fail -eq 0 ] && echo "forget button tests passed" \
                 || { echo "forget button tests FAILED"; exit 1; }
