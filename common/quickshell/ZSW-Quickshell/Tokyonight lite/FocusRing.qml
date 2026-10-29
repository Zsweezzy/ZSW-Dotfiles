import QtQuick

// Keyboard focus ring drawn around its parent. The parent is the control that
// takes activeFocus (a MouseArea, a Slider), so the ring only ever appears
// during Tab/arrow navigation — the pointer never creates it, because nothing
// here reacts to hover.
Rectangle {
    anchors.fill: parent
    anchors.margins: -2
    radius: Tokyo.pillRadius + 2
    color: "transparent"
    border.width: 1
    border.color: Tokyo.blue
    visible: parent !== null && parent.activeFocus
    z: 100
}
