import QtQuick

Item {
    id: root

    property var now

    readonly property real contentW: timeWorst.width

    Text {
        id: time
        anchors.centerIn: parent
        width: parent.width
        height: 15
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: Qt.formatDateTime(root.now, "HH:mm")

        color: Tokyo.fg
        font {
            family: Tokyo.fontFamily
            pixelSize: 13
            bold: true
            letterSpacing: 0.2
        }
    }

    TextMetrics { id: timeWorst; font: time.font; text: "08:88" }
}
