// SettingToggle.qml — one labelled switch in the settings flyout.
//
// The whole row is the target, not just the switch: at this size a 34px switch
// is a hard click, and the label is what the eye aims at.
import QtQuick

Item {
    id: root

    property string label: ""
    property bool checked: false

    signal toggled()

    implicitHeight: 26

    FocusRing { visible: area.activeFocus }

    Text {
        anchors { left: parent.left; right: track.left; rightMargin: 10
                  verticalCenter: parent.verticalCenter }
        text: root.label
        color: Tokyo.fg
        elide: Text.ElideRight
        font { family: Tokyo.fontFamily; pixelSize: 11 }
    }

    Rectangle {
        id: track
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 34
        height: 18
        radius: height / 2
        color: root.checked ? Tokyo.activeTint : Tokyo.bgHighlight
        border.width: 1
        border.color: root.checked ? Tokyo.blue : Tokyo.paneEdge

        Rectangle {
            width: 12
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Tokyo.blue : Tokyo.dim
            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        activeFocusOnTab: true
        function activate() { root.toggled() }
        onClicked: activate()
    }
}
