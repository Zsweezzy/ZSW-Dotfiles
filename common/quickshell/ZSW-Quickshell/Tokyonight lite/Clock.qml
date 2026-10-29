import QtQuick

Module {
    id: root

    fg: Tokyo.fg

    property var now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    implicitWidth: face.contentW + hPad * 2

    ClockFace {
        id: face
        anchors.centerIn: parent
        width: face.contentW
        height: Tokyo.pillHeight
        hovered: root.hovered
        now: root.now
    }
}
