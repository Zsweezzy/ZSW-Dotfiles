import QtQuick

// Label, value and a 0..1 track: the shape both display sliders in the quick
// panel have. The owner holds the value and applies it, because one of them is
// a slow DDC call and the other a compositor command, and neither belongs in a
// widget that a probe can instantiate.
Item {
    id: root

    property string label: ""
    property string valueText: ""
    property real value: 0

    signal moved(real value)

    implicitHeight: 34
    width: parent ? parent.width : 0

    Text {
        id: caption
        text: root.label
        color: Tokyo.dim
        font { family: Tokyo.fontFamily; pixelSize: 11 }
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: caption.verticalCenter
        text: root.valueText
        color: Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
    }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  bottomMargin: 4 }
        height: 4
        radius: 2
        color: Tokyo.bgHighlight
    }
    Rectangle {
        anchors { left: track.left; verticalCenter: track.verticalCenter }
        width: track.width * Math.max(0, Math.min(1, root.value))
        height: track.height
        radius: 2
        color: Tokyo.blue
    }
    Rectangle {
        anchors.verticalCenter: track.verticalCenter
        x: Math.max(0, Math.min(track.width - width,
                                 track.width * Math.max(0, Math.min(1, root.value)) - width / 2))
        width: 10
        height: 10
        radius: 5
        color: Tokyo.fg
    }

    MouseArea {
        id: sliderArea
        anchors.fill: parent
        activeFocusOnTab: true
        onPressed: m => {
            forceActiveFocus()
            moveTo(m.x / width)
        }
        onPositionChanged: m => {
            if (pressed) moveTo(m.x / width)
        }
        // Left/right change the value; up/down are left to the panel's focus
        // navigation, so a slider cannot trap the keyboard.
        Keys.onLeftPressed: moveTo(root.value - 0.02)
        Keys.onRightPressed: moveTo(root.value + 0.02)
        function moveTo(v) {
            root.moved(Math.max(0, Math.min(1, v)))
        }
        FocusRing {}
    }
}
