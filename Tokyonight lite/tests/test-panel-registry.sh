#!/usr/bin/env bash
# Keeps the island modular contract: a module declares its flyout, the flyout
# owns its width, and Island sizes the capsule to that same width. Panels are
# only instantiated on click, so a broken one would otherwise stay hidden until
# someone opens it.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

check() { # check <description> <file> <literal>
    if grep -qF "$3" "$2"; then
        echo "ok   $1"
    else
        echo "FAIL $1"
        fail=1
    fi
}

check "capsule width comes from the loaded panel" Island.qml \
      'readonly property real panelWidth: panelLoader.item ? panelLoader.item.implicitWidth : 0'
check "panel is chosen by module, not by name" Island.qml \
      'sourceComponent: root.panelModule ? root.panelModule.panel : null'
check "clock module declares its panel" Clock.qml 'panel: Component {'
check "audio module declares its panel" Audio.qml 'panel: Component {'
check "sys module declares its panel" Sys.qml 'panel: Component {'

if ! command -v quickshell >/dev/null; then
    echo "skip runtime probe (no quickshell)"
    exit $fail
fi

# The probe resolves its siblings from its own directory, so run it in a temp
# dir of symlinks rather than dropping symlinks into the live config.
TMP=$(mktemp -d /tmp/opencode/qsp-panel.XXXXXX) || exit 1
trap 'rm -rf "$TMP"' EXIT
for f in "$PWD"/*.qml; do ln -s "$f" "$TMP/"; done
cp tests/panel-probe.qml.in "$TMP/panel-probe.qml"

out=$(QT_QPA_PLATFORM=offscreen timeout 20 quickshell -p "$TMP/panel-probe.qml" 2>&1)
clean=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$out")

for want in clock=300 audio=288 sys=320; do
    if grep -qE "(^|: )$want" <<<"$clean"; then
        echo "ok   ${want%%=*} panel is ${want#*=}px wide"
    else
        echo "FAIL ${want%%=*} panel width (wanted ${want#*=}px)"
        grep -E "panel-probe|ERROR|error" <<<"$clean" | tail -5 | sed 's/^/     /'
        fail=1
    fi
done

exit $fail
