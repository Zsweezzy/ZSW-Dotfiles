import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace dots inside the island. The old numbered pills belonged to the
// full-width waybar layout; at capsule size only the count and the active
// workspace read, so each workspace is a dot that widens when active.
Item {
    id: root

    required property ShellScreen screen

    implicitHeight: Tokyo.islandHeight
    implicitWidth: wsRow.implicitWidth

    readonly property var monitor: Hyprland.monitorFor(screen)

    readonly property var workspaces: root.monitor !== null
        ? Hyprland.workspaces.values.filter(ws =>
            ws.monitor !== null
            && (ws.monitor === root.monitor || ws.monitor.name === root.monitor.name)
            && !String(ws.name).startsWith("special:"))
        : []

    Row {
        id: wsRow
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        spacing: 5

        Repeater {
            model: root.workspaces

            delegate: Item {
                id: dot
                required property var modelData
                readonly property var ws: modelData

                width: dot.ws.active ? 22 : 16
                height: parent.height

                Rectangle {
                    id: pill
                    anchors.centerIn: parent
                    // The active workspace is the only one that reads as a
                    // number; at capsule size a row of digits is unreadable
                    // and this keeps inactive workspaces as the dots that show
                    // how many there are.
                    width: dot.ws.active ? 22 : 6
                    height: dot.ws.active ? 16 : 6
                    radius: dot.ws.active ? 8 : 3
                    color: dot.ws.active ? Tokyo.blue : Tokyo.bgHighlight
                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on radius {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        opacity: dot.ws.active ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                        text: dot.ws.name
                        color: Tokyo.islandFill
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font { family: Tokyo.fontFamily; pixelSize: 10; bold: true }
                    }
                }

                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    onClicked: m => {
                        if (m.button === Qt.LeftButton) dot.ws.activate()
                    }
                }
            }
        }
    }
}
