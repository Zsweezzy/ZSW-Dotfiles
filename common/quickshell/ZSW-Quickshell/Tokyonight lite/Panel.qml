import QtQuick

// Base for an island flyout. The panel owns its width (`implicitWidth`), and
// Island.qml reads that same value for the capsule header, so a pill can never
// disagree with the card under it. Adding a module means adding its panel and
// no width entry anywhere else.
Item {
    id: root

    property real padH: Tokyo.panelPadH
    property real padV: Tokyo.panelPadV

    /// Screen the panel is on, set by Island's Loader. Null offscreen (the
    /// test probe), where a panel keeps its declared implicitWidth.
    property var hostScreen: null

    default property alias content: body.data

    implicitHeight: body.implicitHeight + root.padV * 2
    // A flyout declares the narrowest width it works at; the island puts it in
    // a card that is at least as wide as the capsule's pill row, so the item
    // fills that card instead of leaving a dead strip beside it. Offscreen (no
    // parent) it stays at its own width, which is what the probe checks.
    width: parent ? parent.width : implicitWidth

    Column {
        id: body
        x: root.padH
        y: root.padV
        width: root.width - root.padH * 2
        spacing: Tokyo.panelGap
    }
}
