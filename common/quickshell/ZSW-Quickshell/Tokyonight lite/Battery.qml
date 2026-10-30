// Battery.qml — the laptop's charge, as a capsule pill.
//
// UPower's displayDevice is the aggregate the session shows; on a desktop it
// reports a device with `isPresent: false`, so the pill removes itself rather
// than sitting there at 0%. Settings.batteryPill is the off switch.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Module {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: Settings.batteryPill
                                    && root.device !== null
                                    && root.device.isPresent
                                    && root.device.isLaptopBattery

    readonly property int pct: root.device ? Math.round(root.device.percentage) : 0
    readonly property bool charging: root.device !== null
                                     && (root.device.state === UPowerDeviceState.Charging
                                         || root.device.state === UPowerDeviceState.FullyCharged)

    visible: root.present

    readonly property string glyph: root.charging ? "󰂄"
                                    : root.pct >= 90 ? "󰁹"
                                    : root.pct >= 70 ? "󰂀"
                                    : root.pct >= 50 ? "󰁾"
                                    : root.pct >= 30 ? "󰁻"
                                    : root.pct >= 10 ? "󰁺" : "󰂃"

    fragments: [
        {
            text: root.glyph + " " + root.pct + "%",
            color: root.charging ? Tokyo.green
                   : root.pct <= 15 ? Tokyo.red : Tokyo.dim,
        },
    ]
}
