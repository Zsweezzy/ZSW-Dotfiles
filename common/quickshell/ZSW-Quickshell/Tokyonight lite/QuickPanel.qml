import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

// The one flyout: two boxes side by side. Left is status (clock, now playing,
// volume, CPU/RAM), right is the controls (network, Bluetooth, display, power,
// session). It reads the capsule's live modules; every action is a
// property write or an execDetached, so the card can be destroyed at any moment
// without losing state.
Panel {
    id: root

    /// The Quick module in the bar.
    property var quickModule: null

    readonly property var wifiDevice: root.quickModule ? root.quickModule.wifiDevice : null
    readonly property var btAdapter: root.quickModule ? root.quickModule.btAdapter : null
    readonly property var sys: root.quickModule ? root.quickModule.sys : null

    /// The capsule's clock, now-playing and volume modules. Their own flyouts
    /// are gone: this card is the one place they open.
    readonly property var clockModule: root.quickModule ? root.quickModule.clockModule : null
    readonly property var mediaModule: root.quickModule ? root.quickModule.mediaModule : null
    readonly property var audioModule: root.quickModule ? root.quickModule.audioModule : null

    readonly property var networks: {
        if (!root.wifiDevice) return []
        const list = root.wifiDevice.networks.values.filter(n => n.connected || n.known)
        list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                  || (b.signalStrength - a.signalStrength))
        return list
    }

    readonly property var btDevices: {
        if (!root.btAdapter) return []
        const list = root.btAdapter.devices.values.filter(d => d.connected || d.paired)
        list.sort((a, b) => (b.connected - a.connected) || (a.name ?? "").localeCompare(b.name ?? ""))
        return list
    }

    /// Session action armed by its first click; a second click runs it.
    property string confirm: ""

    /// Current powerprofilesctl profile: performance, balanced or power-saver.
    property string powerProfile: ""

    // The control centre is the space-hungry card, so its own padding runs one
    // step tighter than the house values; its boxes follow (see below).
    padH: 12
    padV: 12

    // 42% of the monitor, and never narrower than two boxes need: the device
    // rows read better wide than squeezed into a pill's width. Offscreen (no
    // screen) it falls back to that same minimum.
    implicitWidth: root.hostScreen ? Math.max(680, root.hostScreen.width * 0.42) : 680

    Component.onCompleted: root.scan(true)
    Component.onDestruction: root.scan(false)

    function scan(on) {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = on
        if (root.btAdapter) root.btAdapter.discovering = on
    }

    function pick(network) {
        if (network.connected) network.disconnect()
        else network.connect()
    }

    function setProfile(id) {
        root.powerProfile = id
        setPower.command = ["powerprofilesctl", "set", id]
        setPower.running = true
    }

    function act(id) {
        if (id === "lock") return Session.lock()
        if (id === "suspend") return Quickshell.execDetached(["systemctl", "suspend"])
        if (root.confirm === id) {
            root.confirm = ""
            if (id === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
            else if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
            else if (id === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
        } else {
            root.confirm = id
            confirmTimer.restart()
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirm = ""
    }

    // ---- Two boxes ----
    // The boxes share one height so the shorter one does not leave a bare strip
    // of card beside it. The height comes from the content, never from a box's
    // own height — a Row derives its implicit size from its children's height,
    // so that binding settles at 0.
    Item {
        id: columns
        width: parent.width
        implicitHeight: Math.max(todayBox.implicitHeight, controlBox.implicitHeight)

        Row {
            anchors.fill: parent
            spacing: 10

            Box {
                id: todayBox
                padH: 12
                padV: 12
                gap: 10
                // Wide enough for the calendar's seven day columns, then a share.
                width: Math.max(300, (columns.width - 10) * 0.42)
                height: columns.implicitHeight

                ClockPanel {
                    now: root.clockModule ? root.clockModule.now : new Date()
                    padH: 0
                    padV: 0
                }

                MediaPanel {
                    mediaModule: root.mediaModule
                    padH: 0
                    padV: 0
                    visible: root.mediaModule !== null && root.mediaModule.player !== null
                }

                AudioPanel {
                    audioModule: root.audioModule
                    padH: 0
                    padV: 0
                }

                // ---- System ----
                RowLayout {
                    width: parent.width
                    Text {
                        text: "CPU"
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 11 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Math.round(root.sys ? root.sys.cpuPct : 0) + "%"
                        color: Tokyo.cyan
                        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                    }
                }

                RowLayout {
                    width: parent.width
                    Text {
                        text: "RAM"
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 11 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.sys ? Math.round(root.sys.ramUsed) + " / " + Math.round(root.sys.ramTotal) + " GB" : ""
                        color: Tokyo.green
                        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                    }
                }
            }

            Box {
                id: controlBox
                padH: 12
                padV: 12
                gap: 10
                width: columns.width - todayBox.width - 10
                height: columns.implicitHeight

                // ---- Wi-Fi ----
                RowLayout {
                    width: parent.width

                    Text {
                        text: "Wi-Fi"
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.quickModule && root.quickModule.wifiNetwork
                              ? root.quickModule.wifiNetwork.name : "off"
                        color: root.quickModule && root.quickModule.wifiNetwork ? Tokyo.blue : Tokyo.dim
                        elide: Text.ElideRight
                        Layout.maximumWidth: 160
                        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                    }
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 18
                        radius: 9
                        color: Networking.wifiEnabled ? Tokyo.activeTint : Tokyo.bgHighlight
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            y: 3
                            x: Networking.wifiEnabled ? 17 : 3
                            color: Networking.wifiEnabled ? Tokyo.blue : Tokyo.dim
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            activeFocusOnTab: true
                            function activate() {
                                Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                            onClicked: activate()
                            FocusRing {}
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    visible: Networking.wifiEnabled

                    Repeater {
                        model: root.networks

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 22
                            radius: 6
                            color: rowArea.pressed ? Tokyo.bgHighlight : "transparent"
                            scale: rowArea.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                            Text {
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                width: parent.width - 64
                                text: modelData.name
                                elide: Text.ElideRight
                                color: modelData.connected ? Tokyo.blue
                                                           : (modelData.known ? Tokyo.fg : Tokyo.dim)
                                font { family: Tokyo.fontFamily; pixelSize: 11 }
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 6
                                          verticalCenter: parent.verticalCenter }
                                text: modelData.connected ? "\uf00c"
                                      : (modelData.security === WifiSecurityType.Open ? "" : "\uf023")
                                color: modelData.connected ? Tokyo.blue : Tokyo.dim
                                font { family: Tokyo.fontFamily; pixelSize: 10 }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                activeFocusOnTab: true
                                function activate() { root.pick(modelData) }
                                onClicked: activate()
                                FocusRing {}
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokyo.paneEdge
                }

                // ---- Bluetooth ----
                RowLayout {
                    width: parent.width

                    Text {
                        text: "Bluetooth"
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.btAdapter ? (root.btAdapter.enabled ? root.btAdapter.name : "off") : "none"
                        color: root.btAdapter && root.btAdapter.enabled ? Tokyo.cyan : Tokyo.dim
                        elide: Text.ElideRight
                        Layout.maximumWidth: 160
                        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                    }
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 18
                        radius: 9
                        color: root.btAdapter && root.btAdapter.enabled ? Tokyo.activeTint : Tokyo.bgHighlight
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        visible: root.btAdapter !== null

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            y: 3
                            x: root.btAdapter && root.btAdapter.enabled ? 17 : 3
                            color: root.btAdapter && root.btAdapter.enabled ? Tokyo.cyan : Tokyo.dim
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            activeFocusOnTab: true
                            function activate() {
                                if (root.btAdapter)
                                    root.btAdapter.enabled = !root.btAdapter.enabled
                            }
                            onClicked: activate()
                            FocusRing {}
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    visible: root.btAdapter !== null && root.btAdapter.enabled

                    Repeater {
                        model: root.btDevices

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 22
                            radius: 6
                            color: rowArea.pressed ? Tokyo.bgHighlight : "transparent"
                            scale: rowArea.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                            Text {
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                width: parent.width - 64
                                text: (modelData.name ?? "") !== "" ? modelData.name : modelData.address
                                elide: Text.ElideRight
                                color: modelData.connected ? Tokyo.cyan : (modelData.paired ? Tokyo.fg : Tokyo.dim)
                                font { family: Tokyo.fontFamily; pixelSize: 11 }
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 6
                                          verticalCenter: parent.verticalCenter }
                                text: modelData.batteryAvailable ? Math.round(modelData.battery) + "%"
                                      : (modelData.connected ? "\uf00c" : "")
                                color: modelData.connected ? Tokyo.cyan : Tokyo.dim
                                font { family: Tokyo.fontFamily; pixelSize: 10 }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                activeFocusOnTab: true
                                function activate() {
                                    modelData.connected = !modelData.connected
                                }
                                onClicked: activate()
                                FocusRing {}
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokyo.paneEdge
                }

                // ---- Power profile ----
                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "performance", label: "Performance" },
                            { id: "balanced", label: "Balanced" },
                            { id: "power-saver", label: "Saver" },
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: (parent.width - 12) / 3
                            height: 26
                            radius: Tokyo.pillRadius
                            color: root.powerProfile === modelData.id ? Tokyo.activeTint
                                   : (profileArea.pressed ? Tokyo.bgHighlight : "transparent")
                            scale: profileArea.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            border.width: 1
                            border.color: root.powerProfile === modelData.id ? Tokyo.blue : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.powerProfile === modelData.id ? Tokyo.blue : Tokyo.fg
                                font { family: Tokyo.fontFamily; pixelSize: 10 }
                            }

                            MouseArea {
                                id: profileArea
                                anchors.fill: parent
                                activeFocusOnTab: true
                                function activate() { root.setProfile(modelData.id) }
                                onClicked: activate()
                                FocusRing {}
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokyo.paneEdge
                }

                // ---- Session ----
                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "lock", glyph: "\uf023" },
                            { id: "logout", glyph: "\uf08b" },
                            { id: "suspend", glyph: "\uf186" },
                            { id: "reboot", glyph: "\uf021" },
                            { id: "poweroff", glyph: "\uf011" },
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            width: (parent.width - 24) / 5
                            height: 28
                            radius: Tokyo.pillRadius
                            color: root.confirm === modelData.id ? Tokyo.red : "transparent"
                            scale: sessionArea.pressed ? 0.9 : 1
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: root.confirm === modelData.id ? "Sure?" : modelData.glyph
                                color: root.confirm === modelData.id ? Tokyo.islandFill
                                      : (modelData.id === "poweroff" ? Tokyo.red : Tokyo.fg)
                                font { family: Tokyo.fontFamily; pixelSize: root.confirm === modelData.id ? 11 : 15 }
                            }

                            MouseArea {
                                id: sessionArea
                                anchors.fill: parent
                                activeFocusOnTab: true
                                function activate() { root.act(modelData.id) }
                                onClicked: activate()
                                FocusRing {}
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Processes: power state is not in D-Bus ----

    Process {
        id: readPower
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const value = String(line).trim()
                if (value !== "") root.powerProfile = value
            }
        }
    }
    Process { id: setPower }
}
