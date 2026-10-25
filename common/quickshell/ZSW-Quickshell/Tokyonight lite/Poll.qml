import QtQuick
import Quickshell.Io

Item {
    id: root

    property var command: []

    property int interval: 5000

    property bool active: true

    signal result(string output)

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
        proc.command = ["sh", "-c", root.shellCmd()]
        proc.running = true
    }
}
