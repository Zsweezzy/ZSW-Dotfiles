import QtQuick
import Quickshell.Io

// Pending repo updates, owned by the Quick module so the state and the upgrade
// process outlive the flyout. Closing the card mid-pacman must not kill a
// half-applied transaction, and a panel is destroyed the moment it unmaps.
// The upgrade itself covers every source on this machine (see
// scripts/update-all.sh); only the pacman count is polled here.
Item {
    id: root

    /// One line per pending package, as `checkupdates` prints them
    /// ("pkg old -> new"). The flyout renders them verbatim.
    property var packages: []
    readonly property int count: root.packages.length

    /// True from the script start until the last source finishes.
    property bool updating: false
    /// Current phase ("Repos", "Flatpak", …), or the verdict once it exits.
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
        // One script for every source: repos, Flatpak, AUR and AppImages, in
        // that order. It prints a phase per line, so `status` is the phase
        // being worked on and, at the end, the verdict.
        command: ["bash", Tokyo.scriptDir + "/update-all.sh"]
        stdout: SplitParser { onRead: line => root.status = String(line) }
        stderr: SplitParser { onRead: line => root.status = String(line) }
        onExited: (code, status) => {
            root.updating = false
            if (root.status === "")
                root.status = code === 0 ? "Updated" : "Failed (exit " + code + ")"
            updatesPoll.refresh()
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
