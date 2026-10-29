import QtQuick
import Quickshell
import Quickshell.Hyprland

Variants {
    id: barRoot
    model: Quickshell.screens
    property bool launcherOpen: false
    property bool pickerOpen: false
    property bool clipboardOpen: false
    /// Bumped by shell.qml from the updates keybind; the focused monitor's
    /// island consumes it.
    property int updatesRequest: 0
    /// The focused monitor's capsule width, animated. The launcher card lives
    /// in another window and rescales with it.
    property real capsuleWidth: Tokyo.launcherWidth

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        anchors { top: true; left: true; right: true }
        implicitHeight: Tokyo.barHeight + Tokyo.shadowPad
        exclusiveZone: Tokyo.barHeight
        color: "transparent"

        Tooltip { id: tip }

        Island {
            id: island
            screen: win.screen
            tooltipHost: tip
            window: win
            updatesRequest: barRoot.updatesRequest
            // Only the monitor the flyout opens on gets a squared header.
            launcherOpen: barRoot.launcherOpen
                          && win.screen.name === Hyprland.focusedMonitor?.name
            pickerOpen: barRoot.pickerOpen
                        && win.screen.name === Hyprland.focusedMonitor?.name
            clipboardOpen: barRoot.clipboardOpen
                           && win.screen.name === Hyprland.focusedMonitor?.name
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: Tokyo.barShiftV - Tokyo.shadowPad / 2
            }
        }

        // Only the focused monitor's capsule drives the launcher card, which
        // only ever opens there. `when` false restores the default width.
        Binding {
            target: barRoot
            property: "capsuleWidth"
            value: island.capsuleWidth
            when: win.screen.name === Hyprland.focusedMonitor?.name
        }
    }
}
