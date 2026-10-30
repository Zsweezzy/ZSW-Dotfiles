// Session.qml — the session lock's front door, for anything that is not
// shell.qml.
//
// The lock itself is Lock.qml (a WlSessionLock). It lives in a singleton so the
// control centre's lock button, the idle daemon and the IPC handler all reach
// the same lock object: a second WlSessionLock would be ignored by the
// compositor while the first is locked, and would leave a dead surface behind.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    /// The shell's NotificationStore, set once by shell.qml. The lock surface
    /// reads the unread count off it.
    property var store: null

    readonly property bool locked: lock.locked

    function lock() {
        lock.locked = true
    }

    function unlock() {
        lock.locked = false
    }

    Lock {
        id: lock
        store: root.store
    }
}
