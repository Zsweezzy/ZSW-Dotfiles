pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property string monitorName: Hyprland.focusedMonitor !== null
        ? Hyprland.focusedMonitor.name
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "focusedmon") return
            root.monitorName = event.data.split(",")[0]
        }
    }
}
