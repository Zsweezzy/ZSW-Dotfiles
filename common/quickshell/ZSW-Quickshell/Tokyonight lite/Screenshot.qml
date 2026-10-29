import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Print / Shift+Print. hyprshot, grim and slurp used to do this; wlr-screencopy
// into a layer surface and a grab of the QML scene replaces all three.
//
// The surface is mapped only while a shot is in flight, and the frame is taken
// before anything is drawn on it: the ScreencopyView is still empty when the
// compositor serves the frame. Everything the user sees afterwards is drawn
// from that frozen frame, which is also what gets saved — the selection is a
// crop of it, never a second capture.
PanelWindow {
    id: root

    /// "monitor" saves the whole screen at once, "region" waits for a drag,
    /// "" is closed. shell.qml hands this to the focused monitor only.
    property string mode: ""
    signal done()

    readonly property bool open: root.mode !== ""
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property bool picking: root.mode === "region" && root.ready
    readonly property bool selected: root.sw > 1 || root.sh > 1

    /// The frozen frame has arrived; nothing is drawn before it does.
    property bool ready: false
    property int attempts: 0
    // The crop, in window coordinates.
    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0

    function reset(): void {
        root.ready = false
        root.attempts = 0
        root.sx = 0
        root.sy = 0
        root.sw = 0
        root.sh = 0
    }

    function save(): void {
        const name = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png"
        const path = root.dir + "/" + name
        const kind = root.mode
        // The crop is the region, or the whole frame for a monitor shot, and it
        // grabs at the output's real pixels. done() unmaps this window, so the
        // grab has to finish first: an unmapped surface renders nothing.
        crop.grabToImage(result => {
            if (!result.saveToFile(path)) {
                Quickshell.execDetached(["notify-send", "-a", "screenshot", "-u", "critical",
                                         "Screenshot failed", path])
            } else {
                Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < '" + path + "'"])
                Quickshell.execDetached(["notify-send", "-a", "screenshot",
                                         "Screenshot saved (" + kind + ")", name])
            }
            root.done()
        })
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Mapped only while a shot is in flight: an unmapped surface takes no
    // clicks, and a mapped one has to be rendered for the frame to arrive.
    visible: root.open

    onModeChanged: {
        root.reset()
        if (root.mode === "") capture.captureSource = null
    }

    // A layer surface starts at 1x1 and only takes the screen's size after the
    // first configure, so a capture requested before that records the wrong
    // surface. Retry until the frame lands instead of racing the first commit.
    Timer {
        interval: 60
        repeat: true
        running: root.open && !root.ready
        onTriggered: {
            if (root.attempts++ > 40) {
                Quickshell.execDetached(["notify-send", "-a", "screenshot", "-u", "critical",
                                         "Screenshot failed", "no frame from the compositor"])
                root.done()
                return
            }
            if (root.width !== root.screen.width) return
            if (capture.captureSource !== root.screen) capture.captureSource = root.screen
            else capture.captureFrame()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.done()
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    ScreencopyView {
        id: capture
        anchors.fill: parent
        // No cursor in the picture, and one frame is all this needs.
        paintCursor: false
        live: false
        onHasContentChanged: {
            if (!capture.hasContent || !root.open) return
            root.ready = true
            if (root.mode !== "monitor") return
            // Whole screen: the crop is the whole window, and the window shows
            // exactly the frame it is saving, so this reads as no overlay.
            root.sx = 0
            root.sy = 0
            root.sw = root.width
            root.sh = root.height
            root.save()
        }
    }

    // Everything below is drawn from the frozen frame, so the dimming and the
    // box never end up in the file.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.35
        visible: root.picking
    }

    // The selection, re-rendered from the same frame at full brightness: it
    // reads as a hole in the dimming, and it is the item that gets grabbed.
    ShaderEffectSource {
        id: crop
        x: root.sx
        y: root.sy
        width: root.sw
        height: root.sh
        sourceItem: capture
        sourceRect: Qt.rect(root.sx, root.sy, root.sw, root.sh)
        live: true
        visible: root.selected
    }

    Rectangle {
        x: root.sx
        y: root.sy
        width: root.sw
        height: root.sh
        color: "transparent"
        border.color: Tokyo.blue
        border.width: 1
        visible: root.picking && root.selected
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.picking
        cursorShape: Qt.CrossCursor

        property real ox: 0
        property real oy: 0

        onPressed: mouse => {
            root.sx = mouse.x
            root.sy = mouse.y
            root.sw = 0
            root.sh = 0
            ox = mouse.x
            oy = mouse.y
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            root.sx = Math.min(ox, mouse.x)
            root.sy = Math.min(oy, mouse.y)
            root.sw = Math.abs(mouse.x - ox)
            root.sh = Math.abs(mouse.y - oy)
        }
        onReleased: {
            // A click, not a box: slurp behaved the same, and a 2px crop is
            // never what someone wanted.
            if (root.sw < 8 || root.sh < 8) {
                root.done()
                return
            }
            root.save()
        }
    }
}
