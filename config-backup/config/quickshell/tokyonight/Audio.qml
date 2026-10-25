import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Module {
    id: root

    fg: Tokyo.magenta

    PwObjectTracker {
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

    text: root.muted
          ? "\uf026 " + root.pct + "%"
          : (root.pct >= 67 ? "\uf028 " : "\uf027 ") + root.pct + "%"

    tooltip: !sink ? "" : `${sink.description} ${root.pct}%`

    onWheelTick: dy => {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1,
                           root.volume + (dy > 0 ? 0.05 : -0.05)))
    }
}
