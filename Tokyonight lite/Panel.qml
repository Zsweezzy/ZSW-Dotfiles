import QtQuick

// Base for an island flyout. The panel owns its width (`implicitWidth`), and
// Island.qml reads that same value for the capsule header, so a pill can never
// disagree with the card under it. Adding a module means adding its panel and
// no width entry anywhere else.
Item {
    id: root

    property real padH: Tokyo.panelPadH
    property real padV: Tokyo.panelPadV

    default property alias content: body.data

    implicitHeight: body.implicitHeight + root.padV * 2
    width: implicitWidth

    Column {
        id: body
        x: root.padH
        y: root.padV
        width: root.width - root.padH * 2
        spacing: Tokyo.panelGap
    }
}
