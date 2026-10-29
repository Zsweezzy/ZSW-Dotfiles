import QtQuick
import QtQuick.Layouts

Panel {
    id: root

    /// The Audio module in the bar; the panel reads and writes its sink.
    property var audioModule: null

    readonly property var sink: root.audioModule ? root.audioModule.sink : null
    readonly property real volume: root.audioModule ? root.audioModule.volume : 0
    readonly property bool muted: root.audioModule ? root.audioModule.muted : false
    readonly property int pct: root.audioModule ? root.audioModule.pct : 0

    implicitWidth: 288

    RowLayout {
        width: parent.width

        Text {
            text: "Volume"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 12 }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.muted ? "muted" : root.pct + "%"
            color: root.muted ? Tokyo.red : Tokyo.fg
            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }
    }

    Item {
        id: slider
        width: parent.width
        height: 20

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Tokyo.bgHighlight
        }
        Rectangle {
            anchors { left: track.left; verticalCenter: track.verticalCenter }
            width: track.width * Math.min(1, root.volume)
            height: track.height
            radius: 2
            color: root.muted ? Tokyo.dim : Tokyo.blue
            // Keyboard volume steps jump; this lets the fill
            // glide instead of stuttering.
            Behavior on width {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(slider.width - width,
                                     slider.width * root.volume - width / 2))
            width: 12
            height: 12
            radius: 6
            color: Tokyo.fg
            Behavior on x {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: volumeArea
            anchors.fill: parent
            activeFocusOnTab: true
            onPressed: m => {
                forceActiveFocus()
                applyVolume(m.x)
            }
            onPositionChanged: m => {
                if (pressed) applyVolume(m.x)
            }
            Keys.onLeftPressed: step(-0.05)
            Keys.onRightPressed: step(0.05)
            function applyVolume(x) {
                if (!root.sink || !root.sink.audio) return
                root.sink.audio.volume =
                    Math.max(0, Math.min(1, x / slider.width))
            }
            function step(delta) {
                if (!root.sink || !root.sink.audio) return
                root.sink.audio.volume = Math.max(0, Math.min(1, root.volume + delta))
            }
            FocusRing {}
        }
    }

    RowLayout {
        width: parent.width
        spacing: 10

        Rectangle {
            width: 34
            height: 26
            radius: 13
            color: root.muted ? Tokyo.activeTint : Tokyo.bgHighlight
            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            Text {
                anchors.centerIn: parent
                text: root.muted ? "\uf026" : "\uf028"
                color: root.muted ? Tokyo.red : Tokyo.fg
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                font { family: Tokyo.fontFamily; pixelSize: 14 }
            }

            MouseArea {
                anchors.fill: parent
                activeFocusOnTab: true
                function activate() {
                    if (root.sink && root.sink.audio)
                        root.sink.audio.muted = !root.muted
                }
                onClicked: activate()
                FocusRing {}
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.sink ? root.sink.description : "No output"
            color: Tokyo.dim
            elide: Text.ElideRight
            font { family: Tokyo.fontFamily; pixelSize: 11 }
        }
    }
}
