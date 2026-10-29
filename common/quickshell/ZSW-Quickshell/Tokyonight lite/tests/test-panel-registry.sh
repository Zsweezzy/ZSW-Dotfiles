#!/usr/bin/env bash
# Keeps the island flyout contract: the capsule has one flyout, it owns its
# width, and Island sizes the capsule to that same width. Panels are only
# instantiated on click, so a broken one would otherwise stay hidden until
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

absent() { # absent <description> <file> <literal>
    if grep -qF "$3" "$2"; then
        echo "FAIL $1"
        fail=1
    else
        echo "ok   $1"
    fi
}

check "capsule width comes from the loaded panel" Island.qml \
      'readonly property real panelWidth: panelLoader.item ? panelLoader.item.implicitWidth : 0'
check "panel is chosen by module, not by name" Island.qml \
      'sourceComponent: root.panelModule ? root.panelModule.panel : null'
# A 0-height xdg_popup is a Wayland protocol error, and closing nulls the module
# in the same commit that drops the loader's item.
check "panel surface never collapses to zero height" Island.qml \
      'implicitHeight: Math.max(1, root.surfaceHeight)'
# The flyout is a drawer: the card slides down from behind the capsule inside
# an already-full-height surface, instead of resizing the surface mid-map.
check "flyout slides in as a drawer" Island.qml \
      'y: -height * (1 - reveal)'
# Closing is the same slide reversed: the surface is unmapped by a timer only
# after the animation, because an outside click still unmaps it immediately.
check "close is the reverse slide" Island.qml \
      'property real reveal: popup.visible && !root.closing ? 1 : 0'
# Clicking another pill while one is open morphs between them: the card
# animates its size and the contents crossfade, with no retract or unmap.
check "switching flyouts morphs instead of retracting" Island.qml \
      'root.outgoingModule = root.panelModule'
# The surface is fixed during the morph, so it must hold the larger panel.
check "surface holds both panels while morphing" Island.qml \
      'readonly property real surfaceWidth: Math.max(root.openWidth,'
check "quick module is the one that declares a panel" Quick.qml 'panel: Component {'
check "every pill opens that flyout" Island.qml 'onClicked: root.toggle(quickPill)'
absent "clock has no flyout of its own" Clock.qml 'panel: Component {'
absent "audio has no flyout of its own" Audio.qml 'panel: Component {'
absent "media has no flyout of its own" Media.qml 'panel: Component {'

# The upgrade process outlives the panel: a flyout close mid-pacman must not
# kill a half-applied transaction.
check "updates process lives in the module" Updates.qml \
      'command: ["pkexec", "pacman", "-Syu", "--noconfirm"]'
# A browser publishes MPRIS for any tab that makes sound, so YouTube would
# otherwise take the pill. Only a playing, non-browser player is shown.
check "media pill only follows a playing player" Media.qml \
      'players.find(p => p.isPlaying && !root.isBrowser(p))'
check "media pill knows browser players" Media.qml 'root.isBrowser(p)'
# System stats and updates are data under the quick pill, not pills of their
# own: the bar keeps one control-centre entry instead of three.
check "quick composes the system probe" Quick.qml 'Sys { id: sysData }'
check "quick composes the updates probe" Quick.qml 'Updates { id: updateData }'
# One polkit agent per session, and it is ours: the prompt is bound to the
# agent's flow rather than to a window of its own, and joins the capsule the
# way the launcher does (flush at the bar's height, capsule widened to it).
check "polkit prompt is bound to the agent flow" shell.qml \
      'flow: polkitAgent.flow'
check "polkit prompt joins the capsule" PolkitPrompt.qml \
      'y: root.shown || card.height > 1 ? Tokyo.barHeight : -card.height - 40'
check "polkit card unrolls from the capsule" PolkitPrompt.qml \
      'height: root.shown ? body.implicitHeight + Tokyo.panelPadV * 2 : 0'
check "capsule widens for the polkit prompt" Island.qml \
      'width: root.polkitOpen ? Tokyo.polkitWidth'
# The clipboard picker is a per-monitor layer surface like the launcher, not a
# popup: a popup of the bar cannot hold keyboard focus.
check "clipboard picker is per-monitor" shell.qml 'delegate: Clipboard'

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

for want in clock=300 audio=288 media=300 quick=720; do
    if grep -qE "(^|: )$want" <<<"$clean"; then
        echo "ok   ${want%%=*} panel is ${want#*=}px wide"
    else
        echo "FAIL ${want%%=*} panel width (wanted ${want#*=}px)"
        grep -E "panel-probe|ERROR|error" <<<"$clean" | tail -5 | sed 's/^/     /'
        fail=1
    fi
done

exit $fail
