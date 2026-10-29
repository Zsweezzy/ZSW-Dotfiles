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
      'Math.max(1, Math.max(root.surfaceHeight, root.audioHeight)'
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
# Notifications are this shell's daemon and this shell's centre, not swaync's:
# the bell opens its own panel and the badge is the store's unread count.
check "the bell opens the notification centre" Island.qml \
      'onClicked: root.toggle(bell)'
check "the centre is the bell's own panel" Island.qml 'panel: Component {'
check "the badge is the store's unread count" Island.qml \
      'readonly property int unread: root.store ? root.store.unread : 0'
absent "the bell does not shell out to swaync" Island.qml 'swaync-client'
check "the shell owns the notification daemon" shell.qml \
      'NotificationStore { id: notificationStore }'
check "the bar hands the store to its islands" Bar.qml \
      'store: barRoot.notifications'
check "toasts follow the store" Bar.qml 'store: barRoot.notifications'
absent "clock has no flyout of its own" Clock.qml 'panel: Component {'
absent "audio has no flyout of its own" Audio.qml 'panel: Component {'
absent "media has no flyout of its own" Media.qml 'panel: Component {'

# The upgrade process outlives the panel: a flyout close mid-pacman must not
# kill a half-applied transaction. One script covers every source on the box.
check "updates process lives in the module" Updates.qml \
      'command: ["bash", Tokyo.scriptDir + "/update-all.sh"]'
check "update all upgrades repos" scripts/update-all.sh 'pkexec pacman -Syu'
check "update all upgrades flatpaks" scripts/update-all.sh 'flatpak update -y'
check "update all upgrades the AUR" scripts/update-all.sh 'yay -Sua'
check "update all upgrades AppImages" scripts/update-all.sh 'appimageupdatetool'
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
# Super+Tab is a keybind in Hyprland, so it enters through the IPC handler and
# the bar routes it to the focused monitor's island.
check "Super+Tab toggles the flyout by IPC" shell.qml \
      'function toggleFlyout(): void {'
check "the bar routes the flyout to the focused island" Bar.qml \
      'function onToggleFlyoutRequested(byKeyboard) {'
check "the bar routes Super+N to the focused island" Bar.qml \
      'function onToggleNotificationsRequested(byKeyboard) {'
check "the bar routes Super+A to the focused island" Bar.qml \
      'function onToggleAudioRequested(byKeyboard) {'
# The clipboard picker is a per-monitor layer surface like the launcher, not a
# popup: a popup of the bar cannot hold keyboard focus.
check "clipboard picker is per-monitor" shell.qml 'delegate: Clipboard'

# The audio pill opens the instrument panel: routing and per-app streams do not
# fit in a drawer sized for the control centre.
check "the audio pill opens its card" Island.qml \
      'onClicked: root.toggleAudio()'
# Not a flyout of its own: the card rides in the drawer's popup surface, sharing
# its top line, so there is one window to dismiss and one keyboard owner. It
# sits beside the drawer's left column, where the volume pill is, and must not
# shift the drawer on screen.
check "the audio card hangs beside the drawer" Island.qml \
      'x: Tokyo.flyoutShadowPad'
check "the audio card does not move the drawer" Island.qml \
      'x: Tokyo.flyoutShadowPad + root.audioExtra'
check "the audio card shares the drawer's surface" Island.qml \
      'active: root.audioOpen'
check "the audio card lists running streams" AudioCard.qml 'n.isStream && n.isSink'

# Exclusive fullscreen hides every layer except overlay, so the bar (and the
# popup anchored to it) must live there to stay usable over a game.
check "the bar renders over exclusive fullscreen" Bar.qml \
      'WlrLayershell.layer: WlrLayer.Overlay'
# Overlay also means a pill on every game's screen, so the bar hides while the
# active workspace holds a fullscreen (mode 2/3) window and returns on a card.
check "the bar steps aside under fullscreen" Bar.qml \
      'readonly property bool outOfTheWay:'
check "fullscreen means mode 2 or 3, not maximized" Bar.qml \
      '.filter(c => c.fullscreen >= 2)'
check "the hidden bar is click-through" Bar.qml \
      'mask: Region { item: win.outOfTheWay ? null : island }'
check "the capsule hides with the bar" Bar.qml 'visible: !win.outOfTheWay'
check "an open card brings the bar back" Bar.qml '!island.anyOpen'
# Print/Shift+Print: the shell grabs the frame itself, over every window.
check "the screenshot overlay is an overlay layer" Screenshot.qml \
      'WlrLayershell.layer: WlrLayer.Overlay'
check "a monitor shot saves the frozen frame" Screenshot.qml \
      'crop.grabToImage(result => {'
check "the window is mapped only for a shot" Screenshot.qml 'visible: root.open'
check "a click is not a region" Screenshot.qml 'if (root.sw < 8 || root.sh < 8)'
# Hyprland.monitors is an ObjectModel: indexing it yields undefined, so every
# screen would map with no capture view and time the whole shot out.
check "monitors come from the ObjectModel's values" Screenshot.qml \
      'readonly property var monitors: Hyprland.monitors.values'
# Region mode maps every screen, so the press can land on any of them: each
# window holds every frame and can save a box that crosses outputs.
check "a region holds every monitor's frame on every screen" Screenshot.qml \
      'root.mode === "region" ? root.monitors'
check "Print reaches the focused monitor" shell.qml \
      'root.screenshotScreen = Hyprland.focusedMonitor?.name ?? ""'
# The prompt card joins the capsule's bottom edge: the bar's shadow is clipped
# there, or it darkens the card's top and breaks the join.
check "capsule shadow stops at the prompt seam" Island.qml 'clip: root.polkitOpen'
# Nothing on the bar opens on hover: the audio card is a click/Super+A surface
# like every other card.
absent "the audio pill does not open on hover" Island.qml 'HoverHandler'

# The card lost its calendar, both sliders and the sensor footer, and its
# device lists show only what is already saved or paired.
check "the main pill shows RAM again" Quick.qml 'root.sys.ramPct'
check "Wi-Fi lists only saved or connected networks" QuickPanel.qml \
      'n.connected || n.known'
check "Bluetooth lists only paired or connected devices" QuickPanel.qml \
      'd.connected || d.paired'
absent "no brightness slider in the card" QuickPanel.qml 'Brightness'
absent "no temperature or fan footer" QuickPanel.qml 'fanRpm'
absent "the card has no calendar" ClockPanel.qml 'daysInMonth'
absent "no DDC brightness read at open" QuickPanel.qml 'getvcp'

# Hover is gone everywhere: rows react to keyboard focus and a press. A hover
# colour is how a keyboard-only control centre rots, so it is a hard rule.
for f in *.qml; do
    absent "no hover colour in $f" "$f" 'hoverEnabled'
done

# The Check button queries every source, not only the polled repos.
check "check queries repos" Updates.qml 'checkupdates 2>/dev/null | wc -l'
check "check queries flatpak" Updates.qml 'flatpak remote-ls --updates'
check "check queries the AUR" Updates.qml 'yay -Qua'


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

# The audio card rides in the drawer's surface, so its implicit width is the
# 360px card itself — no shadow padding, the popup carries that.
for want in clock=300 audio=288 media=300 quick=680 notifications=380 audiocard=360; do
    if grep -qE "(^|: )$want" <<<"$clean"; then
        echo "ok   ${want%%=*} panel is ${want#*=}px wide"
    else
        echo "FAIL ${want%%=*} panel width (wanted ${want#*=}px)"
        grep -E "panel-probe|ERROR|error" <<<"$clean" | tail -5 | sed 's/^/     /'
        fail=1
    fi
done

exit $fail
