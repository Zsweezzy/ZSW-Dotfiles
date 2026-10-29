import QtQuick
import Quickshell.Io

// Pending repo updates, owned by the Quick module so the state and the upgrade
// process outlive the flyout. Closing the card mid-pacman must not kill a
// half-applied transaction, and a panel is destroyed the moment it unmaps.
Item {
    id: root

    /// One line per pending package, as `checkupdates` prints them
    /// ("pkg old -> new"). The flyout renders them verbatim.
    property var packages: []
    readonly property int count: root.packages.length

    /// True from the pkexec start until pacman exits.
    property bool updating: false
    /// Last line of pacman's output, or the verdict once it exits.
    property string status: ""

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
