import QtQuick
import Quickshell
import Quickshell.Hyprland

Variants {
    id: barRoot
    model: Quickshell.screens
    property bool launcherOpen: false
    property bool pickerOpen: false
    property bool clipboardOpen: false
    property bool polkitOpen: false
    /// shared NotificationStore (shell.qml) — the daemon, history and toasts
    property var notifications: null
    /// The focused monitor's capsule width, animated. The launcher card lives
    /// in another window and rescales with it.
    property real capsuleWidth: Tokyo.launcherWidth

    /// Super+Tab: open the flyout on the focused monitor, exactly as its pills
    /// do. shell.qml's IpcHandler is the street door; each monitor has its own
    /// island, so the signal is answered only by the focused one.
    signal toggleFlyoutRequested
    function toggleFlyout() { toggleFlyoutRequested() }

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
            // Only the monitor the flyout opens on gets a squared header.
            launcherOpen: barRoot.launcherOpen
                          && win.screen.name === Hyprland.focusedMonitor?.name
            pickerOpen: barRoot.pickerOpen
                        && win.screen.name === Hyprland.focusedMonitor?.name
            clipboardOpen: barRoot.clipboardOpen
                           && win.screen.name === Hyprland.focusedMonitor?.name
            polkitOpen: barRoot.polkitOpen
                        && win.screen.name === Hyprland.focusedMonitor?.name
            store: barRoot.notifications
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: Tokyo.barShiftV - Tokyo.shadowPad / 2
            }
        }

        // The toasts have no pill to hang off, and a PopupWindow can only place
        // itself against an anchor item, so this is the marker they aim at:
        // zero-sized, in the bar's top-right corner, clear of the bar itself.
        Item {
            id: toastAnchor
            anchors {
                top: parent.top; right: parent.right
                topMargin: Tokyo.barHeight + 8; rightMargin: Tokyo.edgeGap + 3
            }
            width: 0
            height: 0
        }

        // One per window so a toast lands on the monitor you are looking at.
        Toast {
            store: barRoot.notifications
            anchorItem: toastAnchor
        }

        // Only the focused monitor's capsule drives the launcher card, which
        // only ever opens there. `when` false restores the default width.
        Binding {
            target: barRoot
            property: "capsuleWidth"
            value: island.capsuleWidth
            when: win.screen.name === Hyprland.focusedMonitor?.name
        }

        Connections {
            target: barRoot
            function onToggleFlyoutRequested() {
                if (win.screen.name === Hyprland.focusedMonitor?.name)
                    island.toggleFlyout()
            }
        }
    }
}
