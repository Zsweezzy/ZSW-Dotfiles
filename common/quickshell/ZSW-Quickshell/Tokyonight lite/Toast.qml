// Toast.qml — the transient notification stack, one window, top right.
//
// One window for the whole stack rather than one per notification: a popup
// window per toast is a compositor surface per toast, and a burst of six
// notifications would open six xdg popups that then have to be closed in the
// right order. One window, one Column, and the rows animate in and out in
// place.
//
// It is deliberately not anchored to a pill: a notification belongs to no
// widget. Quickshell 0.3.2's PopupWindow has no x/y at all — only relativeX/Y
// against an anchor item — so the bar provides a zero-size Item in its
// top-right corner for it to hang off. Edges and gravity both Top|Right puts
// the popup out past the screen edge and PopupAdjustment flips it back, which
// is what makes the popup's top-right land on the corner rather than its
// top-left.
import QtQuick
import Quickshell

PopupWindow {
    id: root

    // The window's clear colour is white by default, so every toast would
    // arrive as a white rectangle with a card on it. Transparent like every
    // other flyout; the cards are the only thing drawn.
    color: "transparent"

    /// the shell-wide store (NotificationStore.qml)
    property var store: null
    /// the bar's zero-size top-right corner marker (Bar.qml: toastAnchor)
    property var anchorItem: null
    /// how many rows fit before the stack is trimmed
    property int maxRows: 4

    // ---------- anchoring ----------
    Component.onCompleted: {
        root.anchor.item = root.anchorItem
        root.anchor.edges = Edges.Top | Edges.Right
        root.anchor.gravity = Edges.Top | Edges.Right
        root.anchor.adjustment = PopupAdjustment.All
    }

    // One Toast per bar window, so one per monitor, and every one of them takes
    // the same notification: the toast belongs on whichever screen you happen
    // to be looking at, and gating that on anything you have to keep in sync
    // means the notification arrives on a screen you are not looking at and
    // reads as "nothing showed up". Duplicates are the cheap failure; a missed
    // notification is not.

    readonly property real padH: 12
    readonly property real padV: 10
    readonly property int gap: 8

    /// The rows on screen, newest at the top.
    ///
    /// Each is a plain { n } wrapper, not the Notification itself: a Repeater
    /// whose model is an array of QObjects would bind to their change signals,
    /// and a notification updating its own body would re-enter the model
    /// binding until QML kills it as a loop. Plain objects have no change
    /// signals, so the array is inert.
    property var rows: []

    readonly property bool anyVisible: rows.length > 0

    // The window itself, not just the box inside it. A PopupWindow starts
    // hidden and nothing in a notification's life cycle sets it visible — it
    // has to follow whether there is anything left to say.
    visible: anyVisible

    implicitWidth: 360
    implicitHeight: column.implicitHeight + padV * 2

    /// One new row per notification that arrives. `n` is the daemon's own
    /// object, so the row can dismiss itself, run one of its actions, and be
    /// told when the notification expired rather than guessing from a timer.
    function push(n) {
        if (n === null || n === undefined) return
        root.rows = [{ n: n }].concat(root.rows)
        root.trim()
    }

    /// Drop the oldest rows past `maxRows`, dismissing them properly first so
    /// the notification is closed on the daemon's side too and not left
    /// resident in a client that thinks it is still being shown.
    function trim() {
        if (root.rows.length <= root.maxRows) return
        for (const row of root.rows.slice(root.maxRows)) close(row.n)
        root.rows = root.rows.slice(0, root.maxRows)
    }

    /// Dismiss on the daemon, tolerating one the daemon has already released: a
    /// Notification throws on any property access once it is closed, and an
    /// uncaught throw here aborts the caller before it drops the row.
    function close(n) {
        if (n === null || n === undefined) return
        try {
            n.dismiss()
        } catch (e) {
            // Already gone; the row still goes.
        }
    }

    function remove(at) {
        // By the delegate's index, never by the daemon's object. That object is
        // destroyed when the client closes the notification, which nulls the
        // row's `n` — so an identity lookup finds nothing and the row then
        // stays on screen forever with every Text blanked. `index` is the
        // Repeater's, and it tracks `rows` on every reassignment.
        if (at < 0 || at >= root.rows.length) return
        const n = root.rows[at].n
        root.rows = root.rows.slice(0, at).concat(root.rows.slice(at + 1))
        close(n)
    }

    Rectangle {
        id: box
        anchors.fill: parent
        visible: root.anyVisible
        color: "transparent"

        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: root.padH; rightMargin: root.padH
                      topMargin: root.padV }
            spacing: root.gap

            Repeater {
                model: root.rows
                delegate: ToastRow {
                    width: column.width
                    store: root.store
                    // Per-urgency, because the client's own expiry is not what
                    // swaync's timeouts honoured: normal 6s, low 5s, critical
                    // and resident until dismissed.
                    timeout: root.store ? root.store.timeoutFor(n) : 6000
                    onDone: root.remove(index)
                }
            }
        }
    }

    Connections {
        target: root.store
        // DND collects without interrupting, and an open centre is already the
        // place the eye is, so a card under it would cover what it announces.
        function onNewNotification(n) {
            if (root.store.dnd || root.store.centreOpen) return
            root.push(n)
        }
    }
}
