import QtQuick
import Quickshell.Io

Item {
    id: root

    property var command: []

    property int interval: 5000

    property bool active: true

    signal result(string output)
    /// Emitted before each run, so a poll that reports a list can start from
    /// empty instead of appending to the previous run's lines.
    signal started()

    function shellCmd() {
        const parts = []
        for (let i = 0; i < root.command.length; i++) {
            const a = String(root.command[i])
            parts.push("'" + a.replace(/'/g, "'\\''") + "'")
        }
        return "(" + parts.join(" ") + ") ; sleep 0.1"
    }

    Process {
        id: proc
        command: ["sh", "-c", root.shellCmd()]

        stdout: SplitParser {
            onRead: msg => root.result(msg)
        }
    }

    Timer {
        id: pollTimer
        interval: root.interval
        repeat: true
        running: root.active && root.command.length > 0
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        if (root.command.length > 0) pollTimer.triggered()
    }

    function refresh() {
        if (root.command.length === 0) return
        root.started()
        proc.command = ["sh", "-c", root.shellCmd()]
        proc.running = true
    }
}
