import QtQuick
import Quickshell

PopupWindow {
    id: root

    visible: false
    color: "transparent"

    readonly property real gap: 6
    readonly property real padH: 20
    readonly property real padV: 14

    property string text: ""

    implicitWidth: label.implicitWidth + padH
    implicitHeight: label.implicitHeight + padV + gap

    Rectangle {
        id: box
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.height - gap
        color: Tokyo.bgDark
        radius: Tokyo.pillRadius
        border.color: Tokyo.bgHighlight
        border.width: 1

        Text {
            id: label
            anchors { fill: parent; margins: 7 }
            text: root.text
            color: Tokyo.fg
            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
            wrapMode: Text.NoWrap
        }
    }

    function showFor(item, txt) {
        root.text = txt
        root.anchor.item = item
        root.anchor.edges = Edges.Bottom
        root.anchor.gravity = Edges.Bottom
        root.visible = true
    }

    function hide() {
        root.visible = false
    }
}
