// SettingsPanel.qml — the settings flyout.
//
// Every switch writes Settings.qml, which persists to JSON immediately. There
// is no Apply: a settings app that can be half-applied is a settings app you
// have to leave and re-enter to trust.
import QtQuick

Panel {
    id: root

    implicitWidth: 320

    Item {
        width: parent.width
        height: 22

        Text {
            anchors { left: parent.left; leftMargin: 4
                      verticalCenter: parent.verticalCenter }
            text: "SETTINGS"
            color: Tokyo.blue
            font { family: Tokyo.fontFamily; pixelSize: 10
                   bold: true; letterSpacing: 1.5 }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Tokyo.bgHighlight
    }

    SettingToggle {
        width: parent.width
        label: "Do Not Disturb"
        checked: Settings.dnd
        onToggled: Settings.dnd = !Settings.dnd
    }

    SettingToggle {
        width: parent.width
        label: "Group notifications by app"
        checked: Settings.groupNotifications
        onToggled: Settings.groupNotifications = !Settings.groupNotifications
    }

    SettingToggle {
        width: parent.width
        label: "Volume / brightness OSD"
        checked: Settings.osdEnabled
        onToggled: Settings.osdEnabled = !Settings.osdEnabled
    }

    SettingToggle {
        width: parent.width
        label: "Battery pill"
        checked: Settings.batteryPill
        onToggled: Settings.batteryPill = !Settings.batteryPill
    }

    SettingToggle {
        width: parent.width
        label: "Low power (slower polls)"
        checked: Settings.lowPower
        onToggled: Settings.lowPower = !Settings.lowPower
    }

    PresetRow {
        width: parent.width
        label: "Lock the session after"
        options: [5, 10, 30, 0]
        current: Settings.lockIdleMinutes
        onPicked: v => Settings.lockIdleMinutes = v
    }

    PresetRow {
        width: parent.width
        label: "Turn the screen off after"
        options: [5, 15, 30, 0]
        current: Settings.dpmsIdleMinutes
        onPicked: v => Settings.dpmsIdleMinutes = v
    }

    PresetRow {
        width: parent.width
        label: "Lock grace after a failed try"
        options: [0, 2, 5, 10]
        current: Settings.lockGraceSeconds
        unit: "s"
        zeroIsOff: false
        onPicked: v => Settings.lockGraceSeconds = v
    }

    // Inline component: the three preset rows are the same widget with a
    // different label and value, and a separate file for 20 lines would only
    // add a name.
    component PresetRow: Column {
        id: preset

        property string label: ""
        property var options: []
        property int current: 0
        property string unit: "m"
        /// A zero option reads "Off" for a duration, "0s" for a delay.
        property bool zeroIsOff: true

        signal picked(int value)

        spacing: 4

        Text {
            width: parent.width
            text: preset.label
            color: Tokyo.dim
            elide: Text.ElideRight
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }

        Row {
            spacing: 4

            Repeater {
                model: preset.options

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool on: preset.current === modelData

                    width: (preset.width - 12) / preset.options.length
                    height: 22
                    radius: 6
                    color: on ? Tokyo.activeTint : "transparent"
                    border.width: 1
                    border.color: on ? Tokyo.blue : Tokyo.paneEdge

                    Text {
                        anchors.centerIn: parent
                        text: modelData === 0 && preset.zeroIsOff
                              ? "Off" : modelData + preset.unit
                        color: on ? Tokyo.blue : Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 10; bold: on }
                    }

                    MouseArea {
                        anchors.fill: parent
                        activeFocusOnTab: true
                        function activate() { preset.picked(modelData) }
                        onClicked: activate()
                        FocusRing {}
                    }
                }
            }
        }
    }
}
