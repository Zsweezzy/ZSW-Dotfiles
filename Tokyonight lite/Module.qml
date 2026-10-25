import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string text: ""
    property string tooltip: ""
    property color fg: Tokyo.fg
    property color bg: Tokyo.pillBg

    property var fragments: []

    property bool hoverStyle: false
    property color hoverBg: Tokyo.bgHighlight
    property color hoverFg: Tokyo.cyan
    /// Inside the island: no pill fill and no shadow, because the capsule
    /// already is the pill. Hovering still recolours the text.
    property bool flat: false

    property int hPad: Tokyo.pillHPad

    property real letterSpacing: 0.2

    property bool hovered: false

    readonly property bool lit: hovered

    signal clicked(int button)

    signal wheelTick(int yDelta)
    signal hoverChanged(bool hovering)

    implicitHeight: Tokyo.pillHeight
    implicitWidth: (root.fragments.length > 0 ? fragRow.implicitWidth : label.implicitWidth)
                   + hPad * 2

    property color color: (root.hoverStyle && root.lit) ? root.hoverBg : root.bg
    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
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
        color: root.flat ? "transparent" : root.color
    }

    Text {
        id: label
        anchors.centerIn: parent
        visible: root.fragments.length === 0
        text: root.text
        color: (hoverStyle && lit) ? root.hoverFg : root.fg
        font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize; letterSpacing: root.letterSpacing }
        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
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
                color: (root.hoverStyle && root.lit) ? root.hoverFg
                                                     : (modelData.color ?? root.fg)
                font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize; letterSpacing: root.letterSpacing }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: {
            root.hovered = true
            root.hoverChanged(true)
        }
        onExited: {
            root.hovered = false
            root.hoverChanged(false)
        }
        onClicked: m => root.clicked(m.button)
        onWheel: w => root.wheelTick(w.angleDelta.y)
    }

    property var tooltipHost: null
    onHoverChanged: hovering => {
        if (tooltipHost === null) return
        if (hovering && root.tooltip !== "") tooltipHost.showFor(root, root.tooltip)
        else tooltipHost.hide()
    }

    onTooltipChanged: {
        if (!lit || tooltipHost === null || root.tooltip === "")
            return
        tooltipHost.showFor(root, root.tooltip)
    }
}
