// SysFlyout.qml — click flyout for the combined gpu/cpu/ram pill.
//
// One tachometer per stat, ring = utilization, hole = the figure that dial is
// about: GPU allocates VRAM in the middle, CPU shows its current clock, RAM
// shows the same allocation in both (there is no second, separate number to
// ring for it). Same popup shape as AudioFlyout: a grab-focus xdg_popup hung
// under the pill that opened it, with the bar's transparent 6px gap strip below.
import QtQuick
import Quickshell

PopupWindow {
    id: root

    visible: false
    grabFocus: true
    color: "transparent"

    /// the Sys.qml pill — read for the numbers, refreshed on open
    property var pill: null

    readonly property real gap: 6
    readonly property real padH: 16
    readonly property real padV: 14
    readonly property real cell: 132

    implicitWidth: root.cell * 3 + root.padH * 2
    implicitHeight: box.height + root.gap

    function toggleFor(item) {
        root.pill = item
        // A dial reading a sample from before the click is a dial showing a lie.
        if (!root.visible && root.pill !== null) root.pill.refresh()
        root.anchor.item = item
        root.anchor.edges = Edges.Bottom
        root.anchor.gravity = Edges.Bottom
        root.visible = !root.visible
    }

    Rectangle {
        id: box
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: row.implicitHeight + root.padV * 2
        color: Tokyo.bgDark
        radius: Tokyo.pillRadius
        border.color: Tokyo.bgHighlight
        border.width: 1

        Row {
            id: row
            anchors {
                left: parent.left; top: parent.top
                leftMargin: root.padH; topMargin: root.padV
            }
            spacing: 8

            // ---------- gpu: ring = utilization, middle = VRAM allocated ----------
            Column {
                width: root.cell
                spacing: 4

                Text {
                    width: parent.width
                    text: "GPU"
                    color: Tokyo.purple
                    horizontalAlignment: Text.AlignHCenter
                    font { family: Tokyo.fontFamily; pixelSize: 11; bold: true; letterSpacing: 1.5 }
                }
                Gauge {
                    width: root.cell
                    height: root.cell
                    accent: Tokyo.purple
                    value: root.pill ? root.pill.gpuUtil / 100 : 0
                    centerText: root.gpuVramText
                    caption: "VRAM"
                }
            }

            // ---------- cpu: ring = utilization, middle = current clock ----------
            Column {
                width: root.cell
                spacing: 4

                Text {
                    width: parent.width
                    text: "CPU"
                    color: Tokyo.cyan
                    horizontalAlignment: Text.AlignHCenter
                    font { family: Tokyo.fontFamily; pixelSize: 11; bold: true; letterSpacing: 1.5 }
                }
                Gauge {
                    width: root.cell
                    height: root.cell
                    accent: Tokyo.cyan
                    value: root.pill ? root.pill.cpuUtil / 100 : 0
                    centerText: root.clockText
                    caption: "CLOCK"
                }
            }

            // ---------- ram: allocation in the middle AND in the ring ----------
            Column {
                width: root.cell
                spacing: 4

                Text {
                    width: parent.width
                    text: "RAM"
                    color: Tokyo.green
                    horizontalAlignment: Text.AlignHCenter
                    font { family: Tokyo.fontFamily; pixelSize: 11; bold: true; letterSpacing: 1.5 }
                }
                Gauge {
                    width: root.cell
                    height: root.cell
                    accent: Tokyo.green
                    value: root.pill ? root.pill.ramPct / 100 : 0
                    centerText: root.ramText
                    caption: "USED"
                }
            }
        }
    }

    // VRAM total is worth the pixels only while the card is reporting it.
    readonly property string gpuVramText: root.pill === null
        ? "-"
        : (root.pill.gpuVram > 0
              ? root.pill.gpuVram + "/" + root.pill.gpuVramTotal + " GB"
              : "n/a")

    readonly property string clockText: root.pill === null || root.pill.cpuGhz <= 0
        ? "-"
        : root.pill.cpuGhz.toFixed(2) + " GHz"

    readonly property string ramText: root.pill === null
        ? "-"
        : root.pill.ramUsed.toFixed(1) + " GB"
}
