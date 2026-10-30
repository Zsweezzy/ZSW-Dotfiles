// Settings.qml — the shell's own preferences, one singleton for the session.
//
// Plain JSON in ~/.config/quickshell/, deliberately outside this config tree:
// the tree is a git repo, and toggling DND should not show up as a diff.
//
// `FileView.text` rather than JsonAdapter: the adapter maps declared QML
// properties onto the file and needs a writeAdapter() call per change, while
// the raw text is one parse and one setText. The file is small and read once.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME")
                                    || Quickshell.env("HOME") + "/.config")
                                   + "/quickshell/tokyonight-settings.json"

    // ---------- notifications ----------
    /// Do Not Disturb: history still fills, no toasts.
    property bool dnd: false
    /// Apps whose notifications never toast. History keeps them.
    property var mutedApps: []
    /// Collapse rows from one app into a group in the centre.
    property bool groupNotifications: true

    // ---------- OSD ----------
    property bool osdEnabled: true

    // ---------- idle ----------
    /// 0 disables auto-lock.
    property int lockIdleMinutes: 10
    /// 0 disables DPMS-off.
    property int dpmsIdleMinutes: 5
    /// Seconds the lock screen waits before it accepts a password again after
    /// a failed try. 0 = immediately.
    property int lockGraceSeconds: 0

    // ---------- bar ----------
    property bool batteryPill: true
    /// Halve the poll rates and shorten animations (Perf.qml reads this).
    property bool lowPower: false

    /// True once the file has been read, so a first-run default is not
    /// mistaken for a user choice.
    property bool loaded: false
    /// Set while adopt() writes the file's values in, so the change handlers
    /// do not immediately write the same file back out.
    property bool _adopting: false

    FileView {
        id: file
        path: root.path
        watchChanges: true
        // The file not existing on a first run is the normal case, not a
        // problem to print on every reload.
        printErrors: false
        onLoaded: root.adopt(file.text)
        onFileChanged: root.adopt(file.text)
    }

    function adopt(text) {
        let o
        try {
            o = JSON.parse(String(text))
        } catch (e) {
            return
        }
        if (o === null || typeof o !== "object") return
        root.loaded = true
        root._adopting = true
        if (typeof o.dnd === "boolean") root.dnd = o.dnd
        if (Array.isArray(o.mutedApps)) root.mutedApps = o.mutedApps.map(String)
        if (typeof o.groupNotifications === "boolean")
            root.groupNotifications = o.groupNotifications
        if (typeof o.osdEnabled === "boolean") root.osdEnabled = o.osdEnabled
        if (Number.isFinite(o.lockIdleMinutes)) root.lockIdleMinutes = o.lockIdleMinutes
        if (Number.isFinite(o.dpmsIdleMinutes)) root.dpmsIdleMinutes = o.dpmsIdleMinutes
        if (Number.isFinite(o.lockGraceSeconds)) root.lockGraceSeconds = o.lockGraceSeconds
        if (typeof o.batteryPill === "boolean") root.batteryPill = o.batteryPill
        if (typeof o.lowPower === "boolean") root.lowPower = o.lowPower
        root._adopting = false
    }

    function save() {
        if (root._adopting) return
        file.setText(JSON.stringify({
            dnd: root.dnd,
            mutedApps: root.mutedApps,
            groupNotifications: root.groupNotifications,
            osdEnabled: root.osdEnabled,
            lockIdleMinutes: root.lockIdleMinutes,
            dpmsIdleMinutes: root.dpmsIdleMinutes,
            lockGraceSeconds: root.lockGraceSeconds,
            batteryPill: root.batteryPill,
            lowPower: root.lowPower,
        }, null, 2) + "\n")
    }

    function isMuted(app) {
        return root.mutedApps.indexOf(String(app)) >= 0
    }

    function setMuted(app, muted) {
        const a = String(app)
        const next = root.mutedApps.filter(x => x !== a)
        if (muted) next.push(a)
        root.mutedApps = next
        root.save()
    }

    function toggleMuted(app) {
        root.setMuted(app, !root.isMuted(app))
    }

    // Every write persists. Bound here rather than at each call site so a new
    // toggle cannot forget it.
    onDndChanged: root.save()
    onMutedAppsChanged: root.save()
    onGroupNotificationsChanged: root.save()
    onOsdEnabledChanged: root.save()
    onLockIdleMinutesChanged: root.save()
    onDpmsIdleMinutesChanged: root.save()
    onLockGraceSecondsChanged: root.save()
    onBatteryPillChanged: root.save()
    onLowPowerChanged: root.save()
}
