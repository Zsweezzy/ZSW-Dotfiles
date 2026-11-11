import QtQuick

Panel {
    id: root

    property var now: new Date()

    implicitWidth: 300

    Text {
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 40; bold: true; letterSpacing: 1 }
    }
    Text {
        text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
        color: Tokyo.dim
        font { family: Tokyo.fontFamily; pixelSize: 12 }
    }
}
