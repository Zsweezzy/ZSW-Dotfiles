import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string text: ""
    property color fg: Tokyo.fg
    property color bg: Tokyo.pillBg

    property var fragments: []

    /// Inside the island: no pill fill and no shadow, because the capsule
    /// already is the pill.
    property bool flat: false

    /// Flyout this module opens, or null. Island.qml instantiates it and sizes
    /// the capsule to its implicitWidth, so pill and card share one width.
    property Component panel: null

    property int hPad: Tokyo.pillHPad

    property real letterSpacing: 0.2

    signal clicked(int button)

    signal wheelTick(int yDelta)

    implicitHeight: Tokyo.pillHeight
    // At least a pill-height-wide target: an icon-only pill (bell, gear) would
    // otherwise be ten pixels wide and the click that misses it does nothing.
    implicitWidth: Math.max((root.fragments.length > 0 ? fragRow.implicitWidth
                                                       : label.implicitWidth) + hPad * 2,
                            Tokyo.pillHeight)
    // A layout sizes a pill; the bell sits in a plain Item instead, where the
    // item would stay 0-wide and only the glyph itself would be clickable.
    width: implicitWidth
    height: implicitHeight

    // Press feedback: the pill dips under the pointer, so a click lands
    // visibly before the flyout slides out.
    scale: mouse.pressed ? 0.94 : 1
    Behavior on scale {
        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
    }

    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        blur: Tokyo.shadowBlur
        offset: Qt.vector2d(0, Tokyo.shadowOffsetY)
        color: Tokyo.shadowColor
        visible: !root.flat
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Tokyo.pillRadius
        color: root.flat ? "transparent"
                          : (mouse.pressed ? Qt.darker(root.bg, 1.45) : root.bg)
    }

    Text {
        id: label
        anchors.centerIn: parent
        visible: root.fragments.length === 0
        text: root.text
        color: root.fg
        font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize; letterSpacing: root.letterSpacing }
    }

    Row {
        id: fragRow
        anchors.centerIn: parent
        spacing: 10
        Repeater {
            model: root.fragments
            delegate: Text {
                required property var modelData

                visible: modelData.visible !== false
                text: modelData.text ?? ""
                color: modelData.color ?? root.fg
                font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize; letterSpacing: root.letterSpacing }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m.button)
        onWheel: w => root.wheelTick(w.angleDelta.y)
    }
}
