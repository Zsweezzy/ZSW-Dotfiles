import QtQuick

// One boxed column inside a flyout. The flyout card is the surface; a box is
// one step up from it and groups the sections that belong together, so a
// control centre reads as two groups instead of one long run of hairlines.
// No outline: the fill alone separates it, like the bar's pills.
//
// Width comes from the owner (a Row of two boxes); height follows the content,
// so nothing clips when a list grows.
Item {
    id: root

    default property alias content: col.data

    property real padH: Tokyo.panelPadH
    property real padV: Tokyo.panelPadV
    property real gap: Tokyo.panelGap

    implicitHeight: col.implicitHeight + root.padV * 2

    Rectangle {
        anchors.fill: parent
        radius: Tokyo.pillRadius
        color: Tokyo.boxFill
    }

    Column {
        id: col
        x: root.padH
        y: root.padV
        width: root.width - root.padH * 2
        spacing: root.gap
    }
}
