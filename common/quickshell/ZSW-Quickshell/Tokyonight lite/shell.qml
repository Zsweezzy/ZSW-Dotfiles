import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool pickerOpen: false
    property bool launcherOpen: false

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.data !== "quickshell-theme-picker") return;
            if (event.name === "openlayer") root.pickerOpen = true;
            else if (event.name === "closelayer") root.pickerOpen = false;
        }
    }

    Process {
        id: pickerProcess
        command: ["quickshell", "-n", "-c", "theme-picker"]
    }

    IpcHandler {
        target: "island"
        // The launcher is a window of this config now, so this is only a
        // property write: no process to start, no layer fade to sit through.
        function toggleLauncher(): void {
            root.launcherOpen = !root.launcherOpen
        }
        function toggleThemePicker(): void {
            pickerProcess.running = !pickerProcess.running
        }
    }

    // Notifications are swaync's: it owns org.freedesktop.Notifications and
    // draws both the toasts and the control centre. The island only toggles
    // its panel, so there is no NotificationServer here to fight it for the
    // bus name.
    // The bar first, so its layer surface sits under the launcher's.
    Bar {
        id: bar
        launcherOpen: root.launcherOpen
        pickerOpen: root.pickerOpen
    }

    // One launcher surface per monitor, like the bar. A window is bound to
    // one output for its whole life: repointing `screen` at the focused
    // monitor rebuilds the layer surface, and Hyprland never sends pointer
    // events to the replacement, so the launcher goes click-dead.
    Variants {
        model: Quickshell.screens
        delegate: Launcher {
            required property ShellScreen modelData
            screen: modelData
            capsuleWidth: bar.capsuleWidth
            open: root.launcherOpen
                  && modelData.name === Hyprland.focusedMonitor?.name
            onDismissed: root.launcherOpen = false
        }
    }
}
