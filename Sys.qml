// Sys.qml — GPU, CPU and RAM in ONE pill (they were three).
//
// Each stat keeps the colour it had on its own pill — purple / cyan / green —
// so this uses Module's `fragments` (coloured spans in a row) rather than its
// single-colour `text`. Each span is "icon + number": a GB figure where the
// kernel gives us one (VRAM, RAM), the utilization where it does not (the CPU).
//
// The dials live in the flyout (SysFlyout.qml), and there is no hover
// tooltip: the pill answers "how much" and the click answers "how much and of
// what", which is the same split Net.qml makes.
import QtQuick

Module {
    id: root

    /// SysFlyout to toggle (created in Bar.qml)
    property var flyoutHost: null

    // Plain properties, not readonly: the Poll handlers below write them.
    property real gpuUtil: 0        // %
    property real gpuVram: 0        // GiB allocated
    property real gpuVramTotal: 0   // GiB total
    property real cpuUtil: 0        // %
    property real cpuGhz: 0         // current clock
    property real ramUsed: 0        // GB
    property real ramTotal: 0       // GB
    property real ramPct: 0         // %

    // gpu.sh prints " n/a" on a card with no amdgpu counters, and gpuVram stays
    // 0 there — so the same expression that prints the VRAM figure falls back
    // to the utilization on its own, no second code path.
    fragments: [
        {
            text: "\ue266 " + (root.gpuVram > 0
                  ? root.gpuVram + "GB"
                  : Math.round(root.gpuUtil) + "%"),
            color: Tokyo.purple,
        },
        {
            text: "\uf2db " + Math.round(root.cpuUtil) + "%",
            color: Tokyo.cyan,
        },
        {
            text: "\uefc5 " + Math.round(root.ramUsed) + "GB",
            color: Tokyo.green,
        },
    ]

    // No hover tooltip. Module shows nothing for an empty one, and the dials are
    // one click away — the same reasoning as Net.qml.
    tooltip: ""

    // ---------- flyout ----------
    onClicked: button => {
        if (button === Qt.LeftButton && root.flyoutHost)
            root.flyoutHost.toggleFor(root)
    }

    /// the flyout's sample is a second old by the time the panel is up
    function refresh() {
        gpuPoll.refresh()
        cpuPoll.refresh()
        memPoll.refresh()
    }

    // ---------- parsers ----------
    /// gpu.sh: " 26% 1/24GiB" (leading space, no trailing newline)
    function applyGpu(out) {
        const parts = String(out).trim().split(/\s+/)
        const util = parseFloat(parts[0])
        if (!isNaN(util)) root.gpuUtil = util
        const vram = String(parts[1] || "").match(/^([\d.]+)\/([\d.]+)/)
        if (vram !== null) {
            root.gpuVram = parseFloat(vram[1])
            root.gpuVramTotal = parseFloat(vram[2])
        }
    }

    /// cpu.sh: pill | "CPU: N%" | "4.50 GHz" | per-core grid rows | legend.
    /// Only the first three are read; the grid has no home now that the pill
    /// has no tooltip (see the header).
    function applyCpu(out) {
        const parts = String(out).split("|")
        const util = parseFloat(String(parts[0]).replace(/[^\d.]/g, ""))
        if (!isNaN(util)) root.cpuUtil = util
        const ghz = parseFloat(parts[2])
        if (!isNaN(ghz)) root.cpuGhz = ghz
    }

    /// mem.sh: pill | "used/total GB (N%)" | top-10 process rows. The header is
    /// all that is read; the rows have no home now that the pill has no tooltip.
    function applyMem(out) {
        const parts = String(out).split("|")
        const head = String(parts[1] || parts[0]).trim()
        const m = head.match(/([\d.]+)\/([\d.]+)\s*GB\s*\((\d+)%\)/)
        if (m !== null) {
            root.ramUsed = parseFloat(m[1])
            root.ramTotal = parseFloat(m[2])
            root.ramPct = parseFloat(m[3])
        }
    }

    Poll {
        id: gpuPoll
        command: [Tokyo.scriptDir + "/gpu.sh"]
        interval: 1000
        onResult: output => root.applyGpu(output)
    }
    Poll {
        id: cpuPoll
        command: [Tokyo.scriptDir + "/cpu.sh"]
        interval: 1000
        onResult: output => root.applyCpu(output)
    }
    Poll {
        id: memPoll
        command: [Tokyo.scriptDir + "/mem.sh"]
        interval: 1000
        onResult: output => root.applyMem(output)
    }
}
