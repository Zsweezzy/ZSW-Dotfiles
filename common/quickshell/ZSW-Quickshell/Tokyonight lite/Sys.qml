import QtQuick

// System data for the Quick flyout: CPU, RAM and the sensor line. It is not a
// pill of its own any more — the quick pill shows the one number worth a
// glance (RAM) and the full picture is one click away, in the same card as
// everything else.
Item {
    id: root

    property real cpuPct: 0
    property real ramUsed: 0
    property real ramTotal: 0

    readonly property real ramPct: root.ramTotal > 0 ? root.ramUsed / root.ramTotal * 100 : 0

    Poll {
        id: cpuPoll
        command: [Tokyo.scriptDir + "/cpu.sh"]
        interval: 2000
        onResult: output => root.cpuPct = parseFloat(output) || 0
    }

    Poll {
        id: memPoll
        command: [Tokyo.scriptDir + "/mem.sh"]
        interval: 30000
        onResult: output => {
            const p = String(output).trim().split("|")
            root.ramUsed = parseFloat(p[0]) || 0
            root.ramTotal = parseFloat(p[1]) || 0
        }
    }
}
