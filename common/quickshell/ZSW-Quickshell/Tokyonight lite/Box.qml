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

    implicitHeight: col.implicitHeight + Tokyo.panelPadV * 2

    Rectangle {
        anchors.fill: parent
        radius: Tokyo.pillRadius
        color: Tokyo.boxFill
    }

    Column {
        id: col
        x: Tokyo.panelPadH
        y: Tokyo.panelPadV
        width: root.width - Tokyo.panelPadH * 2
        spacing: Tokyo.panelGap
    }
}
