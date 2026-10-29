import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

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

    /// Super+Tab / Super+N / Super+A: open the flyout on the focused monitor,
    /// exactly as its pills do. shell.qml's IpcHandler is the street door;
    /// each monitor has its own island, so the signal is answered only by the
    /// focused one.
    signal toggleFlyoutRequested(bool byKeyboard)
    signal toggleNotificationsRequested(bool byKeyboard)
    signal toggleAudioRequested(bool byKeyboard)
    function toggleFlyout(byKeyboard) { toggleFlyoutRequested(byKeyboard) }
    function toggleNotifications(byKeyboard) { toggleNotificationsRequested(byKeyboard) }
    function toggleAudio(byKeyboard) { toggleAudioRequested(byKeyboard) }

    /// Workspaces holding a window in fullscreen mode 2/3 — the mode that
    /// covers the bar. Polled rather than read from Hyprland's cached client
    /// objects (their `fullscreen` goes stale) and not the workspace's
    /// `hasFullscreen` flag (which counts maximized windows too).
    property var fullscreenWorkspaces: []

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        anchors { top: true; left: true; right: true }
        implicitHeight: Tokyo.barHeight + Tokyo.shadowPad
        exclusiveZone: Tokyo.barHeight
        color: "transparent"

        // hyprctl rather than Hyprland.toplevels: the cached client objects keep
        // a stale `fullscreen`, and the workspace's own hasFullscreen counts
        // maximized windows too. One probe on the focused monitor is enough —
        // the answer covers every output.
        Process {
            id: fsProbe
            command: ["hyprctl", "-j", "clients"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        barRoot.fullscreenWorkspaces = JSON.parse(text)
                            .filter(c => c.fullscreen >= 2)
                            .map(c => c.workspace.id)
                    } catch (e) {
                        // A failed probe leaves the last known state alone.
                    }
                }
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: win.screen.name === Hyprland.focusedMonitor?.name
            onTriggered: fsProbe.running = true
        }

        Component.onCompleted: fsProbe.running = true

        // Hyprland hides *top* layers behind an exclusive-fullscreen window and
        // draws overlay ones over it — which is why this bar is an overlay. The
        // price was a pill sitting on every game's screen. Stay out of the way
        // until a card is asked for; then Overlay is exactly what puts the bar
        // (and the popup hanging off it) above the game.
        readonly property var hereWorkspace: Hyprland.monitorFor(win.screen)?.activeWorkspace
        readonly property bool fullscreenHere:
            barRoot.fullscreenWorkspaces.indexOf(hereWorkspace?.id) >= 0
        readonly property bool outOfTheWay:
            fullscreenHere && !island.anyOpen && !barRoot.polkitOpen

        // Mapped but invisible and click-through while out of the way: the
        // surface stays alive, so the keybind can open a popup against a
        // parent that is already mapped instead of racing the remap.
        mask: Region { item: win.outOfTheWay ? null : island }
        // Overlay, not the default top: Hyprland hides top layers behind an
        // exclusive-fullscreen window (a game), and only the overlay layer is
        // allowed above it. The bar and the popups anchored to it stay usable
        // there.
        WlrLayershell.layer: WlrLayer.Overlay
        // An xdg_popup can only be typed into while its parent surface holds
        // the keyboard. The bar takes it only while a flyout is mapped, so
        // returning to the last window is automatic when the card closes.
        WlrLayershell.keyboardFocus: island.keyboardActive ? WlrKeyboardFocus.Exclusive
                                                           : WlrKeyboardFocus.None

        Island {
            id: island
            screen: win.screen
            visible: !win.outOfTheWay
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
            function onToggleFlyoutRequested(byKeyboard) {
                if (win.screen.name === Hyprland.focusedMonitor?.name)
                    island.toggleFlyout(byKeyboard)
            }
            function onToggleNotificationsRequested(byKeyboard) {
                if (win.screen.name === Hyprland.focusedMonitor?.name)
                    island.toggleNotifications(byKeyboard)
            }
            function onToggleAudioRequested(byKeyboard) {
                if (win.screen.name === Hyprland.focusedMonitor?.name)
                    island.toggleAudio(byKeyboard)
            }
        }
    }
}
