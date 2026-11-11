// Osd.qml — the on-screen display for volume, brightness and microphone.
//
// One overlay strip at the bottom centre, mapped only while a value is
// changing, so it costs nothing the rest of the time. It is a layer surface
// spanning the bottom edge with an input mask around the card: a full-width
// surface that took clicks would eat the bottom of every window.
//
// Volume shows itself: the default sink's volume and mute are live objects, so
// a wpctl keybind, a slider in the audio card and a player all land here
// without anyone calling in. Brightness and the microphone have no Quickshell
// service on this box, so their probes run on request (IPC `osd brightness` /
// `osd mic`).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    property bool active: false
    /// "volume" / "brightness" / "mic"
    property string kind: "volume"
    /// 0..100
    property int value: 0
    property bool muted: false
    property string label: ""
    property string glyph: ""

    readonly property color accent: root.kind === "volume" ? Tokyo.magenta
                                    : root.kind === "mic" ? Tokyo.cyan
                                    : Tokyo.blue

    /// The sink's first value arrives while the shell is still wiring itself
    /// up; without this the OSD would flash once on every reload.
    property bool armed: false

    Timer {
        interval: 900
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.active = false
    }

    function flash(kind, value, muted, label, glyph) {
        if (!Settings.osdEnabled) return
        root.kind = kind
        root.value = Math.max(0, Math.min(100, Math.round(value)))
        root.muted = muted
        root.label = label
        root.glyph = glyph
        root.active = true
        hideTimer.restart()
    }

    function showVolume(pct, muted) {
        root.flash("volume", pct, muted, muted ? "Muted" : "Volume",
                   muted ? "󰖁" : pct >= 67 ? "󰕾" : pct > 0 ? "󰖀" : "󰕿")
    }

    function showKind(kind) {
        if (kind === "brightness") brightProbe.running = true
        else if (kind === "mic") micProbe.running = true
        else if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
            root.showVolume(Pipewire.defaultAudioSink.audio.volume * 100,
                            Pipewire.defaultAudioSink.audio.muted)
    }

    // ---------- volume, live ----------
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

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (!root.armed) return
            root.showVolume(Pipewire.defaultAudioSink.audio.volume * 100,
                            Pipewire.defaultAudioSink.audio.muted)
        }
        function onMutedChanged() {
            if (!root.armed) return
            root.showVolume(Pipewire.defaultAudioSink.audio.volume * 100,
                            Pipewire.defaultAudioSink.audio.muted)
        }
    }

    // ---------- brightness ----------
    // `brightnessctl -m` prints
    //   device,class,current,percent,max
    // with percent as "50%", so parseInt is the whole parse.
    Process {
        id: brightProbe
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: brightOut
            waitForEnd: true
        }
        onExited: {
            const pct = parseInt(String(brightOut.text).trim().split(",")[3])
            if (!isNaN(pct))
                root.flash("brightness", pct, false, "Brightness", "󰃠")
        }
    }

    // ---------- microphone ----------
    // `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` prints "Volume: 0.65" and adds
    // " [MUTED]" when muted.
    Process {
        id: micProbe
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            id: micOut
            waitForEnd: true
        }
        onExited: {
            const text = String(micOut.text)
            const m = text.match(/Volume:\s*([0-9.]+)/)
            if (!m) return
            const muted = text.indexOf("[MUTED]") >= 0
            root.flash("mic", parseFloat(m[1]) * 100, muted,
                       muted ? "Microphone muted" : "Microphone",
                       muted ? "󰍭" : "󰍬")
        }
    }

    PanelWindow {
        required property ShellScreen modelData

        screen: modelData
        visible: root.active
                 && modelData.name === Hyprland.focusedMonitor?.name
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 110
        exclusiveZone: 0
        color: "transparent"
        // Above a fullscreen game, like the bar; no keyboard, no input outside
        // the card.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: card }

        Rectangle {
            id: card
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 44 - (1 - card.reveal) * 18
            }
            width: 240
            height: 62
            radius: Tokyo.islandPanelRadius
            color: Tokyo.islandFill
            border.width: 1
            border.color: Tokyo.paneEdge
            opacity: card.reveal

            property real reveal: root.active ? 1 : 0
            Behavior on reveal {
                NumberAnimation { duration: Tokyo.flyoutDuration; easing.type: Easing.OutExpo }
            }

            Row {
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 16; rightMargin: 16; topMargin: 12 }
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph
                    color: root.accent
                    font { family: Tokyo.fontFamily; pixelSize: 20 }
                }

                Column {
                    width: parent.width - 32
                    spacing: 1

                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors { left: parent.left; right: valueText.left
                                      rightMargin: 8
                                      verticalCenter: parent.verticalCenter }
                            text: root.label
                            color: Tokyo.dim
                            elide: Text.ElideRight
                            font { family: Tokyo.fontFamily; pixelSize: 10 }
                        }
                        Text {
                            id: valueText
                            anchors { right: parent.right
                                      verticalCenter: parent.verticalCenter }
                            text: root.muted && root.kind !== "mic"
                                  ? "OFF" : root.value + "%"
                            color: Tokyo.fg
                            font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Tokyo.bgHighlight

                        Rectangle {
                            width: parent.width * (root.muted ? 0 : root.value / 100)
                            height: parent.height
                            radius: 2
                            color: root.accent
                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }
        }
    }
}
