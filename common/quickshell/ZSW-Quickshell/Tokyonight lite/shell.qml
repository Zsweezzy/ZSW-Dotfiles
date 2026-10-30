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
    /// "monitor" / "region" while the screenshot overlay is up, "" otherwise,
    /// and the monitor it belongs to — read once, when the key is pressed.
    property string screenshotMode: ""
    property string screenshotScreen: ""
    /// The selection in layout pixels. Region mode maps every screen, so the
    /// one being dragged has to tell the others what to draw.
    property rect screenshotRect: Qt.rect(0, 0, 0, 0)

    Connections {
        target: Hyprland
        // The theme picker is another process's layer surface: Hyprland's own
        // map/unmap events are the only way this shell learns it is up, and the
        // capsule widens to match it.
        function onRawEvent(event) {
            const open = event.name === "openlayer" ? true
                       : event.name === "closelayer" ? false : null;
            if (open === null) return;
            if (event.data === "quickshell-theme-picker") root.pickerOpen = open;
        }
    }

    Process {
        id: pickerProcess
        command: ["quickshell", "-n", "-c", "ZSW-Quickshell/theme-picker"]
    }

    // `theme set` rewrites ThemeColors.qml, which this shell watches, so a
    // switch from a keybind or the CLI recolours the bar without a restart.
    // Nothing to read back: the file is the state.
    Process { id: themeProcess }

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
        // Super+Tab: the same flyout the capsule's pills open, on the focused
        // monitor. The bar owns the per-monitor islands, so it routes it.
        function toggleFlyout(): void {
            bar.toggleFlyout(true)
        }
        // Super+N / Super+A: the other two surfaces a pointer can open.
        function toggleNotifications(): void {
            bar.toggleNotifications(true)
        }
        function toggleAudio(): void {
            bar.toggleAudio(true)
        }
        // Print / Shift+Print. hyprshot and grim+slurp are gone: the shell
        // grabs the frame itself (Screenshot.qml).
        function screenshot(mode: string): void {
            root.screenshotRect = Qt.rect(0, 0, 0, 0)
            root.screenshotScreen = Hyprland.focusedMonitor?.name ?? ""
            root.screenshotMode = root.screenshotScreen === "" ? "" : mode
        }
        function toggleThemePicker(): void {
            pickerProcess.running = !pickerProcess.running
        }
        // The session lock (Session.qml). `lock` is a keyword-ish name here,
        // so the singleton keeps the verb and the object stays private.
        function lock(): void {
            Session.lock()
        }
        // Bottom-centre OSD: "volume", "brightness" or "mic". Volume also
        // shows itself when the sink changes; this is the door for the other
        // two, and for a keybind that just changed the volume.
        function osd(kind: string): void {
            osdWindow.showKind(kind)
        }
        // The settings flyout, for a keybind and for the docs.
        function settings(): void {
            bar.toggleSettings(true)
        }
        // Do Not Disturb. The centre's button writes the same setting, and
        // Settings.qml is what persists it, so this is only a property write.
        function dnd(on: bool): void {
            Settings.dnd = on
        }
        // `theme set <slug>`, the picker's own command minus the picker.
        // A theme is shell code (theme.conf is sourced), so the slug is held to
        // the shape the picker writes and nothing else. Locked: a reload would
        // drop the lock surface, and the theme can wait.
        function theme(slug: string): void {
            if (!/^[a-z0-9][a-z0-9-]*$/.test(slug)) {
                console.warn("[island] rejected theme slug: " + slug)
                return
            }
            if (Session.locked) return
            themeProcess.command = ["theme", "set", slug]
            themeProcess.running = true
        }
        function close(): void {
            bar.closeFlyout()
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
    // The notification daemon and the history behind the centre. One for the
    // whole shell: `NotificationServer` claims org.freedesktop.Notifications,
    // and a second claim from another bar window's copy would simply fail, so
    // the server and the list it fills have to be the same object everywhere.
    NotificationStore { id: notificationStore }

    // The session lock. It holds no window until `locked` is set, so it costs
    // nothing while the session is open.
    Component.onCompleted: Session.store = notificationStore

    // The desktop itself, under every window: hyprpaper's replacement.
    Wallpaper {}

    // Volume / brightness / microphone feedback, bottom centre, only while a
    // value changes.
    Osd { id: osdWindow }

    // Lock after idle, blank the panel after idle. Reads Settings.qml, so the
    // settings flyout is the only place the thresholds live.
    Idle {}

    // The bar first, so its layer surface sits under the launcher's.
    Bar {
        id: bar
        launcherOpen: root.launcherOpen
        pickerOpen: root.pickerOpen
        clipboardOpen: root.clipboardOpen
        polkitOpen: polkitAgent.isActive
        notifications: notificationStore
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

    // Print / Shift+Print. Region mode maps every screen so a drag can leave
    // the one it started on; monitor mode stays on the focused screen, like
    // hyprshot's `-m active` was.
    Variants {
        model: Quickshell.screens
        delegate: Screenshot {
            required property ShellScreen modelData
            screen: modelData
            mode: (root.screenshotMode === "region"
                   || modelData.name === root.screenshotScreen) ? root.screenshotMode : ""
            // Every screen draws the same selection, so a box dragged onto the
            // next monitor still reads as one box.
            region: root.screenshotRect
            onRegionPicked: (x, y, w, h) => root.screenshotRect = Qt.rect(x, y, w, h)
            onDone: root.screenshotMode = ""
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
