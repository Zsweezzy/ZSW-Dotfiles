import QtQuick
import QtQuick.Layouts

Panel {
    id: root

    /// The Sys module in the bar; the panel reads its live stats.
    property var sysModule: null

    readonly property real cpuPct: root.sysModule ? root.sysModule.cpuPct : 0
    readonly property real ramUsed: root.sysModule ? root.sysModule.ramUsed : 0
    readonly property real ramTotal: root.sysModule ? root.sysModule.ramTotal : 0
    readonly property real ramPct: root.sysModule ? root.sysModule.ramPct : 0

    implicitWidth: 320

    RowLayout {
        width: parent.width
        Text {
            text: "CPU"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 12 }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Math.round(root.cpuPct) + "%"
            color: Tokyo.cyan
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }
    }
    Rectangle {
        width: parent.width
        height: 4
        radius: 2
        color: Tokyo.bgHighlight
        Rectangle {
            width: parent.width * Math.min(1, root.cpuPct / 100)
            height: parent.height
            radius: 2
            color: Tokyo.cyan
            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }
    }

    RowLayout {
        width: parent.width
        Text {
            text: "RAM"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 12 }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: Math.round(root.ramUsed) + " / " + Math.round(root.ramTotal) + " GB"
            color: Tokyo.green
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }
    }
    Rectangle {
        width: parent.width
        height: 4
        radius: 2
        color: Tokyo.bgHighlight
        Rectangle {
            width: parent.width * Math.min(1, root.ramPct / 100)
            height: parent.height
            radius: 2
            color: Tokyo.green
            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }
    }
}
