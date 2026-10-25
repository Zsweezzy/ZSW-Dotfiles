import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    required property ShellScreen screen

    implicitHeight: Tokyo.pillHeight
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
        spacing: Tokyo.moduleMarginH * 2

        Repeater {
            model: root.workspaces

            delegate: Rectangle {
                required property var modelData
                readonly property var ws: modelData

                id: pill
                height: parent.height
                width: Math.max(pillLabel.implicitWidth + Tokyo.wsPad * 2, 36)
                radius: Tokyo.pillRadius
                clip: true

                readonly property bool globallyActive: ws.active
                    && Focus.monitorName !== ""
                    && ws.monitor !== null
                    && ws.monitor.name === Focus.monitorName

                color: globallyActive ? Tokyo.activeTint : (hover.hovered ? Tokyo.bgHighlight : Tokyo.pillBg)
                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                Text {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: pill.ws.id
                    color: pill.globallyActive ? Tokyo.blue : (hover.hovered ? Tokyo.cyan : Tokyo.fg)
                    font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
                    Behavior on color {
                        ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 2
                    color: Tokyo.blue
                    visible: pill.globallyActive
                    radius: height / 2
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: m => {
                        if (m.button === Qt.LeftButton) pill.ws.activate()
                    }
                }
            }
        }
    }
}
