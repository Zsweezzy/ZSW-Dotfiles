import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool pickerOpen: false
    property bool launcherOpen: false
    property bool clipboardOpen: false
    /// swaync's control centre is up. It is the session's notification daemon
    /// (see Island.qml), so the bar only observes its layer surface.
    property bool notifOpen: false

    Connections {
        target: Hyprland
        // The theme picker and swaync's control centre are other processes'
        // layer surfaces: Hyprland's own map/unmap events are the only way
        // this shell learns they are up, and the capsule widens to match them.
        function onRawEvent(event) {
            const open = event.name === "openlayer" ? true
                       : event.name === "closelayer" ? false : null;
            if (open === null) return;
            if (event.data === "quickshell-theme-picker") root.pickerOpen = open;
            else if (event.data === "swaync-control-center") root.notifOpen = open;
        }
    }

    Process {
        id: pickerProcess
        command: ["quickshell", "-n", "-c", "ZSW-Quickshell/theme-picker"]
    }

    IpcHandler {
        target: "island"
        // The launcher is a window of this config now, so this is only a
        // property write: no process to start, no layer fade to sit through.
        function toggleLauncher(): void {
            root.launcherOpen = !root.launcherOpen
        }
        function toggleClipboard(): void {
            root.clipboardOpen = !root.clipboardOpen
        }
        function toggleThemePicker(): void {
            pickerProcess.running = !pickerProcess.running
        }
    }

    // Privileged prompts are the shell's own card (PolkitPrompt), so polkit
    // asks here instead of in a second, differently styled window. One agent
    // per session: hyprpolkitagent must not be started alongside this.
    PolkitAgent {
        id: polkitAgent
        // The prompt is modal: an open launcher or clipboard picker would put
        // a second full-screen grab under it.
        onIsActiveChanged: {
            if (!polkitAgent.isActive) return;
            root.launcherOpen = false;
            root.clipboardOpen = false;
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
        clipboardOpen: root.clipboardOpen
        polkitOpen: polkitAgent.isActive
        notifOpen: root.notifOpen
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

    // Clipboard history, same per-monitor lifecycle as the launcher. It floats
    // instead of joining the capsule: a keybind, not the bar, opens it.
    Variants {
        model: Quickshell.screens
        delegate: Clipboard {
            required property ShellScreen modelData
            screen: modelData
            open: root.clipboardOpen
                  && modelData.name === Hyprland.focusedMonitor?.name
            onDismissed: root.clipboardOpen = false
        }
    }

    // The polkit prompt is the last surface, so it stacks over the launcher's
    // full-screen grab. It joins the capsule like the launcher does.
    Variants {
        model: Quickshell.screens
        delegate: PolkitPrompt {
            required property ShellScreen modelData
            screen: modelData
            flow: polkitAgent.flow
            capsuleWidth: bar.capsuleWidth
            open: polkitAgent.isActive
                  && modelData.name === Hyprland.focusedMonitor?.name
        }
    }
}
