import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

// The one flyout: two boxes side by side. Left is status (clock, now playing,
// volume, CPU/RAM), right is the controls (network, Bluetooth, display, power,
// updates, session). It reads the capsule's live modules; every action is a
// property write or an execDetached, so the card can be destroyed at any moment
// without losing state.
Panel {
    id: root

    /// The Quick module in the bar.
    property var quickModule: null

    readonly property var wifiDevice: root.quickModule ? root.quickModule.wifiDevice : null
    readonly property var btAdapter: root.quickModule ? root.quickModule.btAdapter : null
    readonly property var sys: root.quickModule ? root.quickModule.sys : null
    readonly property var updates: root.quickModule ? root.quickModule.updates : null

    /// The capsule's clock, now-playing and volume modules. Their own flyouts
    /// are gone: this card is the one place they open.
    readonly property var clockModule: root.quickModule ? root.quickModule.clockModule : null
    readonly property var mediaModule: root.quickModule ? root.quickModule.mediaModule : null
    readonly property var audioModule: root.quickModule ? root.quickModule.audioModule : null

    readonly property var networks: {
        if (!root.wifiDevice) return []
        const list = root.wifiDevice.networks.values.slice()
        list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                  || (b.signalStrength - a.signalStrength))
        return list
    }

    readonly property var btDevices: {
        if (!root.btAdapter) return []
        const list = root.btAdapter.devices.values.filter(d => d.connected || d.paired
                                                        || (d.name ?? "") !== "")
        list.sort((a, b) => (b.connected - a.connected) || (a.name ?? "").localeCompare(b.name ?? ""))
        return list
    }

    /// Secured network waiting for a password, or null.
    property var pskNetwork: null
    property string pskText: ""

    /// Session action armed by its first click; a second click runs it.
    property string confirm: ""

    property int brightness: 50
    property bool brightnessRead: false
    property int nightTemp: 6500

    /// Current powerprofilesctl profile: performance, balanced or power-saver.
    property string powerProfile: ""

    // Half the monitor, and never narrower than two boxes need: the Wi-Fi rows
    // and sliders read better wide than squeezed into a pill's width. Offscreen
    // (no screen) it falls back to that same minimum.
    implicitWidth: root.hostScreen ? Math.max(720, root.hostScreen.width / 2) : 720

    Component.onCompleted: root.scan(true)
    Component.onDestruction: root.scan(false)

    function scan(on) {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = on
        if (root.btAdapter) root.btAdapter.discovering = on
    }

    function pick(network) {
        if (network.connected) {
            network.disconnect()
        } else if (network.known || network.security === WifiSecurityType.Open) {
            network.connect()
        } else {
            root.pskNetwork = network
            root.pskText = ""
        }
    }

    function submitPsk() {
        if (!root.pskNetwork) return
        root.pskNetwork.connectWithPsk(root.pskText)
        root.pskNetwork = null
        root.pskText = ""
    }

    function setProfile(id) {
        root.powerProfile = id
        setPower.command = ["powerprofilesctl", "set", id]
        setPower.running = true
    }

    function act(id) {
        if (id === "lock") return Quickshell.execDetached(["hyprlock"])
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
            spacing: Tokyo.panelGap

            Box {
                id: todayBox
                // Wide enough for the calendar's seven day columns, then a share.
                width: Math.max(300, (columns.width - Tokyo.panelGap) * 0.42)
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
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Tokyo.bgHighlight
                    Rectangle {
                        width: parent.width * Math.min(1, (root.sys ? root.sys.cpuPct : 0) / 100)
                        height: parent.height
                        radius: 2
                        color: Tokyo.cyan
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
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
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Tokyo.bgHighlight
                    Rectangle {
                        width: parent.width * Math.min(1, (root.sys ? root.sys.ramPct : 0) / 100)
                        height: parent.height
                        radius: 2
                        color: Tokyo.green
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.sys !== null
                    text: root.sys ? "CPU " + root.sys.cpuTemp + "°   GPU " + root.sys.gpuTemp
                                     + "°   Fan " + root.sys.fanRpm + " rpm" : ""
                    color: Tokyo.islandDim
                    elide: Text.ElideRight
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                }
            }

            Box {
                id: controlBox
                width: columns.width - todayBox.width - Tokyo.panelGap
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
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    visible: Networking.wifiEnabled

                    Repeater {
                        model: root.networks.slice(0, 4)

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 24
                            radius: 6
                            color: hover.containsMouse ? Tokyo.panelFill : "transparent"

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
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.pick(modelData)
                            }
                        }
                    }
                }

                // Password entry for a network that is not stored yet. Same card, no
                // second dialog.
                RowLayout {
                    width: parent.width
                    visible: root.pskNetwork !== null
                    spacing: 6

                    Text {
                        text: root.pskNetwork ? root.pskNetwork.name : ""
                        color: Tokyo.dim
                        elide: Text.ElideRight
                        Layout.maximumWidth: 120
                        font { family: Tokyo.fontFamily; pixelSize: 11 }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        radius: Tokyo.pillRadius
                        color: "transparent"
                        border.width: 1
                        border.color: Tokyo.paneEdge

                        TextInput {
                            id: pskInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Tokyo.fg
                            echoMode: TextInput.Password
                            selectionColor: Tokyo.blue
                            font { family: Tokyo.fontFamily; pixelSize: 11 }
                            focus: root.pskNetwork !== null
                            onAccepted: root.submitPsk()
                            Keys.onEscapePressed: root.pskNetwork = null
                        }
                    }
                    Text {
                        text: "Join"
                        color: Tokyo.cyan
                        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: root.submitPsk()
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
                            onClicked: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    visible: root.btAdapter !== null && root.btAdapter.enabled

                    Repeater {
                        model: root.btDevices.slice(0, 3)

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 24
                            radius: 6
                            color: hover.containsMouse ? Tokyo.panelFill : "transparent"

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
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modelData.connected = !modelData.connected
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokyo.paneEdge
                }

                // ---- Display ----
                SheetSlider {
                    label: "Brightness"
                    valueText: root.brightness + "%"
                    value: root.brightness / 100
                    onMoved: v => {
                        root.brightness = Math.round(v * 100)
                        brightnessTimer.restart()
                    }
                }

                SheetSlider {
                    label: "Night light"
                    // 0 at the slider's left edge means "no tint".
                    valueText: root.nightTemp >= 6500 ? "off" : root.nightTemp + "K"
                    value: (6500 - root.nightTemp) / 4000
                    onMoved: v => {
                        root.nightTemp = Math.round(6500 - v * 4000)
                        tempTimer.restart()
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
                            height: 28
                            radius: Tokyo.pillRadius
                            color: root.powerProfile === modelData.id ? Tokyo.activeTint
                                   : (hover.containsMouse ? Tokyo.panelFill : "transparent")
                            border.width: 1
                            border.color: root.powerProfile === modelData.id ? Tokyo.blue : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.powerProfile === modelData.id ? Tokyo.blue : Tokyo.fg
                                font { family: Tokyo.fontFamily; pixelSize: 10 }
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.setProfile(modelData.id)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokyo.paneEdge
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Tokyo.paneEdge
                }

                // ---- Updates ----
                RowLayout {
                    width: parent.width
                    Text {
                        text: "Updates"
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.updates && root.updates.count > 0
                              ? root.updates.count + " pending" : "up to date"
                        color: root.updates && root.updates.count > 0 ? Tokyo.cyan : Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2
                    visible: root.updates !== null && root.updates.count > 0

                    Repeater {
                        model: root.updates ? root.updates.packages.slice(0, 4) : []
                        delegate: Text {
                            required property string modelData
                            width: parent.width
                            text: modelData
                            color: Tokyo.fg
                            elide: Text.ElideRight
                            font { family: Tokyo.fontFamily; pixelSize: 10 }
                        }
                    }
                    Text {
                        visible: root.updates !== null && root.updates.count > 4
                        text: root.updates ? "+" + (root.updates.count - 4) + " more" : ""
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 10 }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: Tokyo.pillRadius
                    color: root.updates && root.updates.updating ? Tokyo.bgHighlight
                           : (root.updates && root.updates.count > 0 ? Tokyo.activeTint : Tokyo.bgHighlight)

                    Text {
                        anchors.centerIn: parent
                        text: root.updates && root.updates.updating ? "Updating…" : "Update all"
                        color: root.updates && root.updates.updating ? Tokyo.dim
                               : (root.updates && root.updates.count > 0 ? Tokyo.cyan : Tokyo.dim)
                        font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.updates !== null && !root.updates.updating && root.updates.count > 0
                        onClicked: if (root.updates) root.updates.startUpdate()
                    }
                }

                // One line of live pacman output, or why the run failed.
                Text {
                    width: parent.width
                    visible: root.updates !== null && root.updates.status !== ""
                    text: root.updates ? root.updates.status : ""
                    color: root.updates && root.updates.status.startsWith("Failed") ? Tokyo.red : Tokyo.dim
                    elide: Text.ElideRight
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
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
                            height: 30
                            radius: Tokyo.pillRadius
                            color: root.confirm === modelData.id ? Tokyo.red
                                                                 : (hover.containsMouse ? Tokyo.panelFill
                                                                                        : "transparent")
                            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: root.confirm === modelData.id ? "Sure?" : modelData.glyph
                                color: root.confirm === modelData.id ? Tokyo.islandFill
                                      : (modelData.id === "poweroff" ? Tokyo.red : Tokyo.fg)
                                font { family: Tokyo.fontFamily; pixelSize: root.confirm === modelData.id ? 11 : 15 }
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.act(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Processes: display and power state are not in D-Bus ----

    // All three outputs, one line each: "VCP 10 C <now> <max>".
    Process {
        id: readBrightness
        command: ["sh", "-c",
                  "for d in 1 2 3; do ddcutil --display $d getvcp 10 --terse 2>/dev/null; done"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (root.brightnessRead) return
                const fields = String(line).trim().split(/\s+/)
                const value = parseInt(fields[3])
                if (!isNaN(value)) {
                    root.brightness = value
                    root.brightnessRead = true
                }
            }
        }
    }

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

    Timer {
        id: brightnessTimer
        interval: 250
        onTriggered: {
            if (setBrightness.running) return
            setBrightness.command = ["sh", "-c",
                "for d in 1 2 3; do ddcutil --display $d setvcp 10 " + root.brightness
                + " >/dev/null 2>&1 & done; wait"]
            setBrightness.running = true
        }
    }
    Process { id: setBrightness }

    Timer {
        id: tempTimer
        interval: 200
        onTriggered: {
            setTemp.command = ["hyprctl", "hyprsunset", "temperature", String(root.nightTemp)]
            setTemp.running = true
        }
    }
    Process { id: setTemp }
}
