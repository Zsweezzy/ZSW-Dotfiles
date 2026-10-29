import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

// One control-centre pill: network, Bluetooth, display, power, system and
// updates. Four separate pills would not fit the capsule, and this is the one
// place a person looks for any of them. The panel owns nothing: it reads this
// module's live state.
Module {
    id: root

    readonly property var wifiDevice: {
        const devices = Networking.devices.values
        return devices.find(d => d.type === DeviceType.Wifi) ?? null
    }
    readonly property var wifiNetwork: root.wifiDevice
                                       ? (root.wifiDevice.networks.values.find(n => n.connected) ?? null)
                                       : null
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool btOn: root.btAdapter ? root.btAdapter.enabled : false

    /// Live system stats and pending updates. Both are data providers, not
    /// pills: the flyout renders them next to the network controls.
    readonly property var sys: sysData
    readonly property var updates: updateData

    fragments: [
        {
            text: root.wifiOn ? "󰖩" : "󰖪",
            color: root.wifiOn ? (root.wifiNetwork ? Tokyo.blue : Tokyo.dim) : Tokyo.dim,
        },
        {
            text: root.btOn ? "󰂯" : "󰂲",
            color: root.btOn ? Tokyo.cyan : Tokyo.dim,
            visible: root.btAdapter !== null,
        },
        {
            text: root.updates.updating ? "\uf021" : "\uf019 " + root.updates.count,
            color: Tokyo.cyan,
            visible: root.updates.updating || root.updates.count > 0,
        },
    ]

    tooltip: {
        const parts = []
        if (root.wifiNetwork) parts.push(root.wifiNetwork.name)
        if (root.btOn) parts.push("Bluetooth")
        if (root.updates.count > 0) parts.push(root.updates.count + " updates")
        return parts.join(" · ")
    }

    panel: Component {
        QuickPanel { quickModule: root }
    }

    Sys { id: sysData }
    Updates { id: updateData }
}
