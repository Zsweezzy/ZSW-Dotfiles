import QtQuick
import Quickshell.Io

// Pending updates, owned by the Quick module so the state and the upgrade
// process outlive the flyout. Closing the card mid-pacman must not kill a
// half-applied transaction, and a panel is destroyed the moment it unmaps.
//
// Two different jobs live here. The poll keeps the pacman count warm without
// asking for anything, so the pill has a number the moment the card opens. The
// explicit check is what the Check button runs: it asks every source at once,
// including the two (Flatpak, AUR) that are too slow to poll, and hands the
// card one line to explain the number.
Item {
    id: root

    /// One line per pending package, as `checkupdates` prints them
    /// ("pkg old -> new"). The flyout renders them verbatim.
    property var packages: []
    /// Counts from the last explicit check, by source. Repos are not read from
    /// here: `packages` is the same list, kept fresh by the poll.
    property var counts: ({})
    readonly property int count: root.packages.length
        + (root.counts.flatpak || 0) + (root.counts.aur || 0)

    /// What the last check found, source by source, or "" when nothing is
    /// pending. Empty is also the "not checked yet" state, so the card hides
    /// the line instead of claiming zero everywhere.
    readonly property string breakdown: {
        const parts = []
        if (root.packages.length > 0) parts.push("repos " + root.packages.length)
        if (root.counts.flatpak > 0) parts.push("flatpak " + root.counts.flatpak)
        if (root.counts.aur > 0) parts.push("aur " + root.counts.aur)
        return parts.join(" · ")
    }

    /// True from the script start until the last source finishes.
    property bool updating: false
    /// True while the Check button's multi-source query runs.
    property bool checking: false
    /// Current phase ("Repos", "Flatpak", …), or the verdict once it exits.
    property string status: ""

    Poll {
        id: updatesPoll
        command: ["checkupdates"]
        interval: Perf.ms(30 * 60 * 1000)
        onStarted: root.packages = []
        onResult: line => {
            const text = String(line).trim()
            if (text !== "") root.packages = root.packages.concat([text])
        }
    }

    // The explicit check. Repos go through checkupdates as well, so the list
    // and the count can never disagree; Flatpak and AUR have no cached list
    // here, only a count, because the button is what acts on them.
    Process {
        id: checker
        command: ["sh", "-c",
            "printf 'repos %s\\n' \"$(checkupdates 2>/dev/null | wc -l)\";" +
            "printf 'flatpak %s\\n' \"$(flatpak remote-ls --updates 2>/dev/null | wc -l)\";" +
            "printf 'aur %s\\n' \"$(yay -Qua 2>/dev/null | wc -l)\""]
        stdout: SplitParser {
            onRead: line => {
                const parts = String(line).trim().split(" ")
                if (parts.length !== 2) return
                root.counts = Object.assign({}, root.counts, {
                    [parts[0]]: Number(parts[1]) || 0,
                })
            }
        }
        onExited: {
            root.checking = false
            updatesPoll.refresh()
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
            root.counts = ({})
            updatesPoll.refresh()
        }
    }

    function checkAll() {
        if (root.checking || root.updating) return
        root.checking = true
        root.counts = ({})
        root.status = ""
        checker.running = true
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
