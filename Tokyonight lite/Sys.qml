import QtQuick

Module {
    id: root

    property real cpuPct: 0
    property real ramUsed: 0
    property real ramTotal: 0

    readonly property real ramPct: root.ramTotal > 0 ? root.ramUsed / root.ramTotal * 100 : 0

    fragments: [
        {
            text: "\uf2db " + Math.round(root.cpuPct) + "%",
            color: Tokyo.cyan,
        },
        {
            text: "\uefc5 " + Math.round(root.ramPct) + "%",
            color: Tokyo.green,
        },
    ]

    tooltip: ""

    panel: Component {
        SysPanel { sysModule: root }
    }

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
