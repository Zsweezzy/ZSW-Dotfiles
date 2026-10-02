// PowerMode.qml — the low/full power profile pill.
//
// power-mode.sh lives in the hypr tree, not this one, and reports the session's
// power mode on stdout and flips it on `toggle`. The mode is read back out of
// the kernel on every call, so there is no state kept here to drift out of step
// with the hardware: the pill is a readout and the click is the switch.
//
// Two states, both in colours the bar already wears — a green leaf for the
// power-saving half, a blue flash for the full one. Unknown is a bare dash in
// the neutral foreground rather than a guess, because a wrong answer here is a
// wrong answer about what the machine is doing to itself.
import QtQuick
import Quickshell

Module {
    id: root

    /// Absolute, and built from HOME like Tokyo.scriptDir: a quickshell-spawned
    /// process may not inherit a PATH worth having. This is the one script the
    /// bar calls that does not live in this config's own scripts/ directory.
    readonly property string cmd:
        Quickshell.env("HOME") + "/.config/hypr/scripts/power-mode.sh"

    // "" until the first status parses — the pill never claims a mode it has
    // not actually read.
    property string mode: ""
    property string profile: ""
    property string gpu: ""

    readonly property bool known: root.mode === "low" || root.mode === "full"
    readonly property bool low: root.mode === "low"

    fragments: [
        {
            text: root.known ? (root.low ? "\uf06c LOW" : "\uf0e7 FULL") : "—",
            color: root.known ? (root.low ? Tokyo.green : Tokyo.blue) : Tokyo.fg,
        },
    ]

    tooltip: root.known
        ? `Power mode: ${root.mode}\nProfile: ${root.profile || "?"}\nGPU: ${root.gpu || "?"}\nClick to switch to ${root.low ? "full" : "low"}`
        : "Power mode: unknown\nClick to toggle"

    // ---------- status ----------
    // 4 s rather than the 1 s the Sys stats use: each run spawns a shell that
    // talks to power-profiles-daemon and reads sysfs, and the mode only moves
    // when someone clicks — and a click re-polls on its own anyway.
    Poll {
        id: poll
        command: [root.cmd, "status"]
        interval: 4000
        onResult: output => root.applyLine(output)
    }

    /// status prints one key=value per line and Poll hands them over one line at
    /// a time (its stdout is a SplitParser), so each line updates the field it
    /// names and the order they arrive in does not matter. A line that is not
    /// key=value is dropped, and the pill keeps the last thing it understood.
    function applyLine(out) {
        const line = String(out).trim()
        const eq = line.indexOf("=")
        if (eq < 1) return
        const key = line.slice(0, eq)
        const value = line.slice(eq + 1)
        if (key === "mode") root.mode = value
        else if (key === "profile") root.profile = value
        else if (key === "gpu") root.gpu = value
    }

    // ---------- click ----------
    onClicked: button => {
        if (button !== Qt.LeftButton) return
        // Flip the pill on the spot, then let the confirm read tell the truth.
        // `toggle` takes a moment (a D-Bus set plus a sysfs write), so reading
        // status straight after it would just re-read the mode we left — the
        // optimistic-then-confirm shape Settings.qml already uses for the SSID
        // button and the two radios.
        if (root.known) root.mode = root.low ? "full" : "low"
        Quickshell.execDetached([root.cmd, "toggle"])
        confirm.start()
    }

    Timer {
        id: confirm
        interval: 1200
        onTriggered: poll.refresh()
    }
}