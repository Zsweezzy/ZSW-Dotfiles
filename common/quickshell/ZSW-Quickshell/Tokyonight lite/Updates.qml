import QtQuick
import Quickshell
import Quickshell.Io

// Pending repo updates. The module owns the upgrade process, not the panel:
// closing the flyout while pacman runs must not kill a half-applied
// transaction, and a panel is destroyed the moment it unmaps.
Module {
    id: root

    /// One line per pending package, as `checkupdates` prints them
    /// ("pkg old -> new"). The panel renders them verbatim.
    property var packages: []
    readonly property int count: root.packages.length

    /// True from the pkexec start until pacman exits.
    property bool updating: false
    /// Last line of pacman's output, or the verdict once it exits.
    property string status: ""

    visible: root.updating || root.count > 0
    fg: Tokyo.cyan
    text: root.updating ? "\uf021" : "\uf019 " + root.count
    tooltip: root.updating ? "Updating…" : root.count + " updates pending"

    panel: Component {
        UpdatesPanel { updatesModule: root }
    }

    Poll {
        id: updatesPoll
        command: ["checkupdates"]
        interval: 30 * 60 * 1000
        onStarted: root.packages = []
        onResult: line => {
            const text = String(line).trim()
            if (text !== "") root.packages = root.packages.concat([text])
        }
    }

    Process {
        id: updater
        command: ["pkexec", "pacman", "-Syu", "--noconfirm"]
        stdout: SplitParser { onRead: line => root.status = String(line) }
        stderr: SplitParser { onRead: line => root.status = String(line) }
        onExited: (code, status) => {
            root.updating = false
            root.status = code === 0 ? "Updated" : "Failed (exit " + code + ")"
            if (code === 0) updatesPoll.refresh()
        }
    }

    function startUpdate() {
        if (root.updating) return
        root.updating = true
        root.status = ""
        updater.running = true
    }

    function refresh() {
        updatesPoll.refresh()
    }
}
