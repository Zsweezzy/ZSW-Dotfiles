// Perf.qml — the one place poll rates are decided.
//
// Every poller used to pick its own interval, which meant "make the shell
// cheaper" was a grep and a guess. `ms()` is the multiplier: normal is 1x,
// Settings.lowPower doubles every interval. It is deliberately not a
// per-poller knob — a policy with one switch is the one people use.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property real pollScale: Settings.lowPower ? 2 : 1

    function ms(interval) {
        return Math.round(interval * root.pollScale)
    }
}
