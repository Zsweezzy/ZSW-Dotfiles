// Island.qml — saneAspect-style dynamic island for the tokyonight bar.
//
// One near-black capsule at the top centre holds the whole bar: workspace dots,
// clock, volume, cpu/ram. Clicking a section grows a panel under the capsule.
//
// The panel is its own xdg_popup, not part of the bar's layer surface, for two
// reasons: the bar is 34px tall and cannot hold a panel, and a layer surface
// grown to panel height would swallow clicks across the top of the screen even
// where it is transparent. A popup only takes input over its own rectangle and
// the compositor dismisses it on an outside click for free.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Item {
    id: root

    required property var screen
    property var tooltipHost: null
    /// True on the monitor the launcher window is on, while it is mapped.
    property bool launcherOpen: false
    /// True on the monitor the theme picker is on, while it is mapped.
    property bool pickerOpen: false

    /// "" | "clock" | "audio" | "sys"
    property string panel: ""

    /// Width of the panel that is open (or would open). The capsule is the
    /// panel's header, so it takes this width while a panel is showing.
    readonly property real panelWidth: root.panel === "clock" ? 300
                                     : root.panel === "audio" ? 288
                                     : root.panel === "sys" ? 320
                                     : 268

    width: capsule.width
    height: Tokyo.islandHeight

    readonly property var now: clockPill.now

    /// Width the capsule is drawing right now.
    readonly property real capsuleWidth: capsule.width

    function toggle(name) {
        if (!popup.visible) {
            root.panel = name
            popup.visible = true
            Qt.callLater(() => card.forceActiveFocus())
        } else if (root.panel === name) {
            root.close()
        } else {
            root.panel = name
        }
    }

    function close() {
        popup.visible = false
        root.panel = ""
    }

    /// Monday-first offset of the 1st of the month, and the month's length.
    function firstOffset(d) {
        return (new Date(d.getFullYear(), d.getMonth(), 1).getDay() + 6) % 7
    }
    function daysInMonth(d) {
        return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
    }

    RectangularShadow {
        anchors.fill: capsule
        radius: capsule.radius
        blur: Tokyo.shadowBlur
        offset: Qt.vector2d(0, Tokyo.shadowOffsetY)
        color: Tokyo.shadowColor
    }

    Rectangle {
        id: capsule
        anchors.verticalCenter: parent.verticalCenter
        // The launcher and picker cards are exactly as wide as this; widening
        // the capsule while one is open lets the card's square top join the
        // capsule's square bottom edge instead of poking out under a narrow pill.
        width: root.pickerOpen ? Tokyo.pickerWidth
                                 : root.launcherOpen ? Tokyo.launcherWidth
                                 : popup.visible ? root.panelWidth
                                 : row.implicitWidth + Tokyo.islandPadH * 2
        Behavior on width {
            enabled: !popup.visible
            NumberAnimation {
                duration: (root.launcherOpen || root.pickerOpen)
                          ? Tokyo.expandDuration : Tokyo.collapseDuration
                easing.type: Easing.OutCubic
            }
        }
        height: Tokyo.islandHeight
        radius: height / 2
        // While a panel is open the capsule is the panel's header, so its
        // bottom corners square off into the card (which is at least as wide).
        // The launcher's window carries the same header shape.
        bottomLeftRadius: popup.visible || root.launcherOpen || root.pickerOpen ? 0 : height / 2
        bottomRightRadius: popup.visible || root.launcherOpen || root.pickerOpen ? 0 : height / 2
        Behavior on bottomLeftRadius {
            NumberAnimation { duration: Tokyo.collapseDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: Tokyo.collapseDuration; easing.type: Easing.OutCubic }
        }
        color: Tokyo.islandFill

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 14

            Workspaces {
                screen: root.screen
                Layout.alignment: Qt.AlignVCenter
            }

            Clock {
                id: clockPill
                flat: true
                hoverStyle: true
                hPad: 0
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle("clock")
            }

            Audio {
                id: audioPill
                flat: true
                hoverStyle: true
                hPad: 0
                tooltipHost: root.tooltipHost
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle("audio")
            }

            Sys {
                id: sysPill
                flat: true
                hoverStyle: true
                hPad: 0
                tooltipHost: root.tooltipHost
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.toggle("sys")
            }

            // Notifications live in swaync, so the bell is a toggle for its
            // control centre rather than a panel of our own — the count is the
            // only state quickshell keeps.
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight

                Module {
                    id: bell
                    text: "󰂚"
                    flat: true
                    hoverStyle: true
                    hPad: 0
                    tooltip: "Notifications"
                    tooltipHost: root.tooltipHost
                    onClicked: Quickshell.execDetached(["swaync-client", "-t", "-sw"])
                }

                Rectangle {
                    visible: bellCount.value > 0
                    anchors { right: parent.right; top: parent.top
                              topMargin: -3; rightMargin: -5 }
                    width: Math.max(12, badgeText.implicitWidth + 6)
                    height: 12
                    radius: height / 2
                    color: Tokyo.blue
                    // Pops in when the first notification lands.
                    scale: visible ? 1 : 0.4
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                    }

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: bellCount.value > 99 ? "99+" : String(bellCount.value)
                        color: Tokyo.islandFill
                        font { family: Tokyo.fontFamily; pixelSize: 8; bold: true }
                    }
                }

                Poll {
                    id: bellCount
                    property int value: 0
                    // swaync-client prints the count without a newline, and a
                    // line parser only emits complete lines — the echo flushes it.
                    command: ["sh", "-c", "swaync-client -c -sw; echo"]
                    interval: 2000
                    onResult: line => {
                        const n = parseInt(String(line).trim())
                        bellCount.value = isNaN(n) ? 0 : n
                    }
                }
            }
        }
    }

    PopupWindow {
        id: popup
        color: "transparent"
        visible: false
        implicitWidth: card.width
        implicitHeight: card.height

        // An xdg_popup dismisses itself on an outside click, and that write
        // drops the binding on `visible` — so the state has to follow the
        // window, not the other way round.
        onVisibleChanged: if (!visible && root.panel !== "") root.panel = ""

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: root.close()
        }

        Component.onCompleted: {
            popup.anchor.item = capsule
            popup.anchor.edges = Edges.Bottom
            popup.anchor.gravity = Edges.Bottom
            popup.anchor.adjustment = PopupAdjustment.All
        }

        Rectangle {
            id: card
            focus: true
            Keys.onEscapePressed: root.close()

            width: root.panelWidth
            height: body.implicitHeight + 32
            // No width/height animation here: the popup is its own surface and
            // resizing it mid-map renders a sliver before the compositor
            // catches up. Only the content fades.
            radius: Tokyo.islandPanelRadius
            // Square at the top: the capsule is the panel's header, is exactly
            // this wide and meets this edge, so the two read as one shape.
            topLeftRadius: 0
            topRightRadius: 0
            color: Tokyo.islandFill
            clip: true

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 16; rightMargin: 16; topMargin: 16 }
                spacing: 14
                opacity: popup.visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                // ---------- clock ----------
                Column {
                    width: parent.width
                    visible: root.panel === "clock"
                    spacing: 12

                    Text {
                        text: Qt.formatDateTime(root.now, "HH:mm")
                        color: Tokyo.fg
                        font { family: Tokyo.fontFamily; pixelSize: 40; bold: true; letterSpacing: 1 }
                    }
                    Text {
                        text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }

                    Column {
                        width: parent.width
                        spacing: 6

                        Text {
                            text: Qt.formatDateTime(root.now, "MMMM yyyy")
                            color: Tokyo.fg
                            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
                        }

                        Row {
                            Repeater {
                                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                delegate: Text {
                                    required property string modelData
                                    width: 36
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: Tokyo.islandDim
                                    font { family: Tokyo.fontFamily; pixelSize: 11 }
                                }
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 7

                            Repeater {
                                model: 42

                                delegate: Item {
                                    required property int index

                                    readonly property int day: index - root.firstOffset(root.now) + 1
                                    readonly property bool inMonth: day >= 1 && day <= root.daysInMonth(root.now)
                                    readonly property bool today: inMonth && day === root.now.getDate()

                                    width: 36
                                    height: 24
                                    visible: inMonth

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: today ? Tokyo.activeTint : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: day
                                            color: today ? Tokyo.blue : Tokyo.fg
                                            font {
                                                family: Tokyo.fontFamily; pixelSize: 11
                                                bold: today
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- audio ----------
                Column {
                    width: parent.width
                    visible: root.panel === "audio"
                    spacing: 12

                    RowLayout {
                        width: parent.width

                        Text {
                            text: "Volume"
                            color: Tokyo.dim
                            font { family: Tokyo.fontFamily; pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: audioPill.muted ? "muted" : audioPill.pct + "%"
                            color: audioPill.muted ? Tokyo.red : Tokyo.fg
                            Behavior on color {
                                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }
                            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
                        }
                    }

                    Item {
                        id: slider
                        width: parent.width
                        height: 20

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Tokyo.bgHighlight
                        }
                        Rectangle {
                            anchors { left: track.left; verticalCenter: track.verticalCenter }
                            width: track.width * Math.min(1, audioPill.volume)
                            height: track.height
                            radius: 2
                            color: audioPill.muted ? Tokyo.dim : Tokyo.blue
                            // Keyboard volume steps jump; this lets the fill
                            // glide instead of stuttering.
                            Behavior on width {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(slider.width - width,
                                                     slider.width * audioPill.volume - width / 2))
                            width: 12
                            height: 12
                            radius: 6
                            color: Tokyo.fg
                            Behavior on x {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: m => applyVolume(m.x)
                            onPositionChanged: m => {
                                if (pressed) applyVolume(m.x)
                            }
                            function applyVolume(x) {
                                if (!audioPill.sink || !audioPill.sink.audio) return
                                audioPill.sink.audio.volume =
                                    Math.max(0, Math.min(1, x / slider.width))
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: 34
                            height: 26
                            radius: 13
                            color: audioPill.muted ? Tokyo.activeTint : Tokyo.bgHighlight
                            Behavior on color {
                                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: audioPill.muted ? "\uf026" : "\uf028"
                                color: audioPill.muted ? Tokyo.red : Tokyo.fg
                                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                font { family: Tokyo.fontFamily; pixelSize: 14 }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (audioPill.sink && audioPill.sink.audio)
                                        audioPill.sink.audio.muted = !audioPill.muted
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: audioPill.sink ? audioPill.sink.description : "No output"
                            color: Tokyo.dim
                            elide: Text.ElideRight
                            font { family: Tokyo.fontFamily; pixelSize: 11 }
                        }
                    }
                }

                // ---------- system ----------
                Column {
                    width: parent.width
                    visible: root.panel === "sys"
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        Text {
                            text: "CPU"
                            color: Tokyo.dim
                            font { family: Tokyo.fontFamily; pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(sysPill.cpuPct) + "%"
                            color: Tokyo.cyan
                            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Tokyo.bgHighlight
                        Rectangle {
                            width: parent.width * Math.min(1, sysPill.cpuPct / 100)
                            height: parent.height
                            radius: 2
                            color: Tokyo.cyan
                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        Text {
                            text: "RAM"
                            color: Tokyo.dim
                            font { family: Tokyo.fontFamily; pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(sysPill.ramUsed) + " / " + Math.round(sysPill.ramTotal) + " GB"
                            color: Tokyo.green
                            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Tokyo.bgHighlight
                        Rectangle {
                            width: parent.width * Math.min(1, sysPill.ramPct / 100)
                            height: parent.height
                            radius: 2
                            color: Tokyo.green
                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
