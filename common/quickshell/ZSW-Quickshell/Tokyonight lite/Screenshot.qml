import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Print / Shift+Print. hyprshot, grim and slurp used to do this; wlr-screencopy
// into a layer surface and a grab of the QML scene replaces all three.
//
// The surface is mapped only while a shot is in flight, and the frame is taken
// before anything is drawn on it: the ScreencopyViews are still empty when the
// compositor serves the frame. Everything the user sees afterwards is drawn
// from that frozen frame, which is also what gets saved — the selection is a
// crop of it, never a second capture.
PanelWindow {
    id: root

    /// "monitor" saves the whole screen at once, "region" waits for a drag,
    /// "" is closed.
    property string mode: ""
    /// The selection in layout pixels, shared by every screen so the other
    /// windows can draw the same box.
    property rect region: Qt.rect(0, 0, 0, 0)
    signal regionPicked(real x, real y, real w, real h)
    signal done()

    readonly property bool open: root.mode !== ""
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property bool picking: root.mode === "region" && root.ready
    readonly property bool selected: root.sel.width > 1 || root.sel.height > 1

    /// The frozen frame has arrived; nothing is drawn before it does.
    property bool ready: false
    property int attempts: 0
    /// Set by the window that took the press: only it has a local selection.
    property bool dragging: false
    // The selection, in this window's coordinates.
    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0

    // Hyprland's geometry, not the window's: a 2x output is 1920 wide here and
    // 3840 in the file. `.values` because monitors is an ObjectModel, not an
    // array: indexing it directly yields undefined.
    readonly property var monitors: Hyprland.monitors.values ?? []
    readonly property var own: {
        for (let i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name === root.screen.name) return root.monitors[i]
        return null
    }
    readonly property real ownX: root.own ? root.own.x : 0
    readonly property real ownY: root.own ? root.own.y : 0
    /// The bounding box of every monitor, so the frames lay out like the desk.
    readonly property rect box: {
        const ms = root.monitors
        if (ms.length === 0) return Qt.rect(0, 0, 0, 0)
        let x0 = ms[0].x, y0 = ms[0].y
        let x1 = x0 + ms[0].width, y1 = y0 + ms[0].height
        for (let i = 1; i < ms.length; i++) {
            x0 = Math.min(x0, ms[i].x)
            y0 = Math.min(y0, ms[i].y)
            x1 = Math.max(x1, ms[i].x + ms[i].width)
            y1 = Math.max(y1, ms[i].y + ms[i].height)
        }
        return Qt.rect(x0, y0, x1 - x0, y1 - y0)
    }
    /// What this window is showing as selected: its own drag, or the one the
    /// other window is dragging, moved into its coordinates.
    readonly property rect sel: root.dragging
        ? Qt.rect(root.sx, root.sy, root.sw, root.sh)
        : Qt.rect(root.region.x - root.ownX, root.region.y - root.ownY,
                  root.region.width, root.region.height)

    function reset(): void {
        root.ready = false
        root.attempts = 0
        root.dragging = false
        root.sx = 0
        root.sy = 0
        root.sw = 0
        root.sh = 0
    }

    function screenFor(name: string): var {
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
        return null
    }

    function pick(x: real, y: real, w: real, h: real): void {
        root.dragging = true
        root.sx = x
        root.sy = y
        root.sw = w
        root.sh = h
        root.regionPicked(x + root.ownX, y + root.ownY, w, h)
    }

    /// Every frame is in; a monitor shot saves the screen as it is.
    function settle(): void {
        if (!root.open || root.ready) return
        for (let i = 0; i < views.count; i++)
            if (!views.itemAt(i).hasContent) return
        root.ready = true
        if (root.mode !== "monitor") return
        root.pick(0, 0, root.width, root.height)
        root.save()
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

    onModeChanged: root.reset()

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
            for (let i = 0; i < views.count; i++)
                if (!views.itemAt(i).hasContent) views.itemAt(i).captureFrame()
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

    // Every monitor's frame, laid out like the desk: a region can be dragged
    // across screens whichever one the press landed on, and every window holds
    // all of them so the drag can be saved from where it started. A monitor
    // shot only needs its own.
    Item {
        id: layout
        x: root.box.x - root.ownX
        y: root.box.y - root.ownY
        width: root.box.width
        height: root.box.height

        Repeater {
            id: views
            model: root.open
                ? (root.mode === "region" ? root.monitors : (root.own ? [root.own] : []))
                : []
            delegate: ScreencopyView {
                required property var modelData
                x: modelData.x - root.box.x
                y: modelData.y - root.box.y
                width: modelData.width
                height: modelData.height
                // No cursor in the picture, and one frame is all this needs.
                captureSource: root.screenFor(modelData.name)
                paintCursor: false
                live: false
                onHasContentChanged: root.settle()
            }
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
        x: root.sel.x
        y: root.sel.y
        width: root.sel.width
        height: root.sel.height
        sourceItem: layout
        sourceRect: Qt.rect(root.sel.x - layout.x, root.sel.y - layout.y,
                            root.sel.width, root.sel.height)
        live: true
        visible: root.selected
    }

    Rectangle {
        x: root.sel.x
        y: root.sel.y
        width: root.sel.width
        height: root.sel.height
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
            ox = mouse.x
            oy = mouse.y
            root.pick(mouse.x, mouse.y, 0, 0)
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            // The press holds the pointer, so the drag keeps reporting here
            // even once it leaves this screen.
            root.pick(Math.min(ox, mouse.x), Math.min(oy, mouse.y),
                      Math.abs(mouse.x - ox), Math.abs(mouse.y - oy))
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
