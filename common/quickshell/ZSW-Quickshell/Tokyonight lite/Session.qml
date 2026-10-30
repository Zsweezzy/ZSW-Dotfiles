// Session.qml — the session lock's front door, for anything that is not
// shell.qml.
//
// The lock itself is Lock.qml (a WlSessionLock). It lives in a singleton so the
// control centre's lock button, the idle daemon and the IPC handler all reach
// the same lock object: a second WlSessionLock would be ignored by the
// compositor while the first is locked, and would leave a dead surface behind.
//
// A config reload destroys the lock surface with the rest of the config, so the
// state is also kept in a marker file: the generation that starts while it says
// locked locks again. Without that, saving any .qml file (or switching theme)
// unlocked the session.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    /// The shell's NotificationStore, set once by shell.qml. The lock surface
    /// reads the unread count off it.
    property var store: null

    readonly property bool locked: lock.locked

    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
                                         || Quickshell.env("HOME") + "/.local/state")
                                      + "/quickshell/locked"

    FileView {
        id: marker
        path: root.statePath
        printErrors: false
        onLoaded: if (marker.text.trim() === "1" && !root.locked) root.lock()
    }

    // Every way into and out of the lock goes through `locked`, including PAM
    // in LockSurface, so this is the only place the marker has to be written.
    onLockedChanged: marker.setText(root.locked ? "1\n" : "0\n")

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
