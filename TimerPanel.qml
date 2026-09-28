// TimerPanel.qml — the timer list + the "new timer" form, with no frame.
//
// Extracted from TimerWindow.qml so it could be shared by the clock flyout's
// timers cell and the standalone window over one TimerState singleton instead
// of two hand-kept copies. The host owns the frame and the title row; the only
// host left is ClockFlyout's QuadCell, which already has a title row and a rule
// in the same place. The window, its SUPER + SHIFT + T bind and the `timer` IPC
// target that opened it are gone — so `maxListHeight` and the unpinned branch of
// `listCap` below have no host left either, and exist only because removing them
// was not what was asked for.
//
// What the second host bought was list capacity: the window was as tall as its
// timers needed, while the flyout's pane is sized by the clock pane's content
// next to it and so caps the list. That cap is now silent — see `listCap`.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    /// the manual box was clicked — the host puts the keyboard in it
    signal fieldActivated()
    /// a timer was started, so a host that clears its form on close can reset
    signal formChanged()

    /// cap the list and clip it; -1 grows with the number of timers. Ignored
    /// while `pinFormToBottom` is set — then the cap comes from the space.
    property int maxListHeight: -1
    /// the host has room for the big readout and the hint line
    property bool roomy: true
    /// row height. The window can afford 46 px; the flyout's pane is half of a
    /// 464 px panel and the list is capped at two rows, so 36 px is the honest
    /// choice — it still holds the countdown, the "of mm:ss" line and the
    /// progress bar.
    property int rowH: 46

    /// The host's box is taller than this panel's content and wants the form
    /// pinned to the bottom of it, with the list at the top and the slack
    /// between: "what is running" and "set one up" as two ends of one pane
    /// rather than one stack floating in the middle. The window host leaves
    /// this off — it is exactly as tall as its content, so there is no slack to
    /// spend.
    property bool pinFormToBottom: false

    // ---------------- geometry ----------------

    readonly property real gap: 8
    /// the "1-30 min" hint under the form is the tallest thing in it
    readonly property real tail: creator.y + creator.height

    // A positioner is never nested inside another one (see TimerCreator.qml),
    // and a binding that reads an unset positioner's y once is how this panel
    // ends up a block too short. Measuring from the last anchored child keeps
    // the height honest no matter what polish order Qt picks.
    implicitHeight: root.tail
    // Only `top` is anchored, never `top`+`bottom`: anchoring both would make
    // the anchors own the height, and assigning to `height` on top of that is
    // a binding loop. So "fill the host" is expressed here instead.
    height: root.pinFormToBottom ? parent.height : implicitHeight

    /// How far down the list may go. Unpinned, that is the host's `maxListHeight`
    /// and nothing else. Pinned, it is the gap between the top of the panel and
    /// the rule above the form, so the list runs down to the slider instead of
    /// stopping short and leaving a hole in the middle of the pane.
    ///
    /// Derived, never a constant: the pane's height is itself measured off the
    /// clock pane's font metrics, so a hard-coded row count is wrong the moment
    /// either side changes — and wrong here means either a gap or rows running
    /// under the form.
    ///
    /// There is no overflow line any more. It used to read "+N more — full list
    /// in the timer window" and point at `TimerWindow.qml`, which is gone, so it
    /// was removed rather than reworded. That leaves the cap *silent*: past the
    /// rows that fit, the next one simply is not drawn and nothing says so. The
    /// alternatives were a count somewhere that survives (the host's title row)
    /// or letting the list grow, and both are a design change rather than a
    /// deletion — so this is a known gap, not an oversight.
    readonly property real listCap: root.pinFormToBottom
        ? Math.max(root.rowH, creatorRule.y - root.gap - 3)
        : root.maxListHeight

    /// how many rows fit under the cap; -1 = unlimited
    readonly property int capacity: root.listCap < 0
        ? -1
        : Math.max(1, Math.floor((root.listCap + root.gap) / (root.rowH + root.gap)))

    /// running timers the cap is not showing. Drawn nowhere — see `listCap` —
    /// but kept, because it is the input any overflow affordance needs and
    /// recomputing it is the easy half of that job.
    readonly property int hidden: TimerState.timers.length - Math.min(
        TimerState.timers.length, root.capacity < 0 ? TimerState.timers.length : root.capacity)

    // ---------------- the list ----------------

    Item {
        id: rowsArea
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.capacity < 0
            ? (TimerState.active
                ? TimerState.timers.length * (root.rowH + root.gap) - root.gap
                : emptyLine.implicitHeight)
            : Math.min(
                root.listCap,
                TimerState.active
                    ? TimerState.timers.length * (root.rowH + root.gap) - root.gap
                    : emptyLine.implicitHeight)
        // Only clip when capped: with no cap the rows define the height, and
        // clipping would shave the progress bar off the last one.
        clip: root.capacity > 0

        Text {
            id: emptyLine
            anchors { left: parent.left; right: parent.right; top: parent.top }
            visible: !TimerState.active
            text: root.capacity < 0
                ? "nothing running — set one below"
                : "nothing running"
            color: Tokyo.trayGlyph
            font { family: Tokyo.fontFamily; pixelSize: 11 }
        }

        Repeater {
            id: rows
            model: TimerState.timers

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property var t: modelData

                // A Repeater hands out no geometry of its own and the parent is
                // a plain Item, so place the row by hand.
                width: rowsArea.width
                height: root.rowH
                y: index * (root.rowH + root.gap)
                visible: root.capacity < 0 || index < root.capacity
                radius: 6
                color: "transparent"

                readonly property bool fired: row.t.fired
                readonly property bool paused: row.t.paused && !row.t.fired
                readonly property color accent: row.fired
                    ? (row.paused ? Tokyo.trayGlyph : Tokyo.green)
                    : (row.paused ? Tokyo.yellow : Tokyo.blue)

                RowLayout {
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 4; rightMargin: 4
                        verticalCenter: parent.verticalCenter
                        verticalCenterOffset: -2   // clears the progress bar
                    }
                    spacing: 8

                    Text {
                        text: row.fired ? "\uf00c" : (row.paused ? "\uf04b" : "\uf04c")
                        color: row.accent
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }

                    Column {
                        spacing: 0
                        Layout.fillWidth: true

                        Text {
                            text: row.fired
                                ? "done"
                                : TimerState.fmt(TimerState.remainingMs(row.t))
                            color: row.accent
                            font { family: Tokyo.fontFamily; pixelSize: 16; bold: true }
                        }
                        Text {
                            text: row.fired
                                ? "of " + TimerState.fmt(row.t.totalMs)
                                : (row.paused
                                    ? "paused · of " + TimerState.fmt(row.t.totalMs)
                                    : "of " + TimerState.fmt(row.t.totalMs))
                            color: Tokyo.trayGlyph
                            font { family: Tokyo.fontFamily; pixelSize: 9 }
                        }
                    }

                    PillButton {
                        glyph: row.fired ? "\uf067" : (row.paused ? "\uf04b" : "\uf04c")
                        accent: row.fired ? Tokyo.green : Tokyo.yellow
                        onClicked: row.fired
                            ? TimerState.nudge(row.t.id, 1)
                            : TimerState.togglePause(row.t.id)
                    }
                    PillButton {
                        glyph: "\uf067"        // plus
                        accent: Tokyo.cyan
                        onClicked: TimerState.nudge(row.t.id, 1)
                    }
                    PillButton {
                        glyph: "\uf068"        // times
                        accent: Tokyo.magenta
                        onClicked: TimerState.stop(row.t.id)
                    }
                }

                // progress bar
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: 4; rightMargin: 4; bottomMargin: 2 }
                    height: 3
                    radius: 2
                    color: Tokyo.bgHighlight
                    Rectangle {
                        width: parent.width * TimerState.progress(row.t)
                        height: parent.height
                        radius: parent.radius
                        color: row.accent
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }
    }

    // ---------------- the form ----------------

    Rectangle {
        id: creatorRule
        anchors { left: parent.left; right: parent.right }
        height: 1
        color: TimerState.active ? Tokyo.hairline : "transparent"
        // Directly above the form when the form is pinned to the bottom,
        // directly below the list when it is not. A `y` binding rather than a
        // `top` anchor because this needs *two* branches and an anchor bound to
        // a conditional keeps the value it was first given.
        y: root.pinFormToBottom
            ? creator.y - root.gap - 1
            : rowsArea.bottom + root.gap
    }

    TimerCreator {
        id: creator
        anchors { left: parent.left; right: parent.right }
        roomy: root.roomy
        // Bottom-anchored in pin mode, chained off the rule otherwise. `y` for
        // the same reason as the rule: two branches, and neither of them reads
        // the other in the same direction, so there is no loop either way.
        y: root.pinFormToBottom
            ? parent.height - height
            : creatorRule.y + 1 + root.gap
        onStarted: root.formChanged()
        onFieldActivated: root.fieldActivated()
    }

    // ---------------- host hooks ----------------

    function focusField() {
        creator.focusField()
    }

    /// a flyout that closes on an outside click would otherwise reopen with
    /// half-typed minutes still in the box.
    function reset() {
        creator.clear()
    }
}
