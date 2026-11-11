// Lock.qml — the session lock, one WlSessionLock for the whole shell.
//
// The surface is created per output by the compositor when `locked` turns true;
// LockSurface.qml draws it and owns PAM. Keeping the lock here, next to the
// bar, means the IPC handler can lock the session with no second process and
// no hyprlock config to drift.
//
// The old hyprlock bind in ~/.config/hypr is a different repo; it still works
// and is not touched. Bind Super+L to `island lock` when this is adopted.
import QtQuick
import Quickshell
import Quickshell.Wayland

WlSessionLock {
    id: root

    /// The shell's NotificationStore, passed to every surface.
    property var store: null

    locked: false

    LockSurface {
        lock: root
        store: root.store
    }
}
