// Audio.qml — the audio pill: sink volume readout, wheel control, flyout.
//
//   format          {icon} {volume}%
//   format-muted    \uf026 {volume}%
//   format-icons    [\uf027, \uf027, \uf028]   (threshold at 67%)
//   click/wheel     opens the AudioFlyout (per-app volume, in/out devices)
//   right/middle    same flyout — there is no separate popup anymore
//   scroll          volume ±5%, clamped to the shared overboost ceiling
//   tooltip         : "{desc} {volume}%" (hidden while the flyout is open)
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Module {
    id: root

    fg: Tokyo.magenta

    // Bind the default sink so its audio properties (volume/muted) are valid.
    PwObjectTracker {
        id: tracker
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            tracker.objects = [Pipewire.defaultAudioSink]
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int pct: Math.round(volume * 100)

    /// popup flyout to toggle (AudioFlyout, created in Bar.qml)
    property var flyoutHost: null
    /// true while the flyout popup is visible (used to mute the hover tooltip)
    property bool flyoutOpen: false

    text: root.muted
          ? "\uf026 " + root.pct + "%"
          : (root.pct >= 67 ? "\uf028 " : "\uf027 ") + root.pct + "%"

    tooltip: root.flyoutOpen || !sink ? "" : `${sink.description} ${root.pct}%`

    Connections {
        target: root.flyoutHost
        function onVisibleChanged() {
            root.flyoutOpen = root.flyoutHost.visible
        }
    }

    // Every button opens the same flyout. The old audio-popup binary existed
    // because the flyout was a bash clone that could not be toggled from the
    // bar; the real flyout toggleFor() anchors itself to this pill, so there
    // is nothing left for a second panel to do.
    onClicked: () => {
        if (root.flyoutHost) root.flyoutHost.toggleFor(root)
    }

    onWheelTick: dy => {
        if (!sink || !sink.audio) return
        const ceiling = AudioStates.overboost ? 1.5 : 1
        const vol = Math.max(0, Math.min(ceiling,
                           root.volume + (dy > 0 ? 0.05 : -0.05)))
        sink.audio.volume = vol
    }
}