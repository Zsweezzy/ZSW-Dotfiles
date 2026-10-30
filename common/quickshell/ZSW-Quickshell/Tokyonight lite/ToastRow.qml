// ToastRow.qml — one notification in the transient stack. 
//
// Flat layout: absolute x/y with widths derived from the card's own width, and
// the card's height derived from the text column's implicitHeight. A nested
// layout (a Column holding an Item that holds another Column) renders the card
// and the icon and silently drops the glyphs, because two layout engines end up
// assigning y to the same item.
//
// A toast says what happened; the notification centre is where actions live, so
// the only controls here are the body (default action) and the ×.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    /// The daemon's Notification for this row. Required, not assigned: a
    /// Repeater fills a delegate's required properties from the matching key of
    /// `[{n: notification}]`.
    required property var n
    /// The row's own index in the stack; required for the same reason.
    required property int index
    /// the store, for the icon map and dismiss-by-notification
    property var store: null
    /// how long this row stays, in ms. 0 = until dismissed.
    property int timeout: 6000

    /// Emitted when the row has finished leaving. `dismissMe` is true only for
    /// the ×: a timeout hides the toast and leaves the notification in the
    /// centre, exactly like swaync.
    signal done(bool dismissMe)

    /// True once the row has decided to leave, so `done()` fires exactly once
    /// even when the ×, the timer and the daemon's close land together.
    property bool leaving: false
    function leave(dismissMe) {
        if (root.leaving) return
        root.leaving = true
        root.done(dismissMe === true)
    }

    readonly property color accent: n !== null && n !== undefined
                                    && n.urgency === NotificationUrgency.Critical
                                  ? Tokyo.red : Tokyo.blue

    /// 0 at construction, 1 once it is up. The card's x is driven off this same
    /// number, so the fade and the slide cannot disagree about where the row is.
    property real shown: 0
    visible: root.shown > 0.001

    implicitHeight: card.height

    Behavior on shown { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Rectangle {
        id: card
        width: parent.width
        // The taller of the icon and the text block, plus padding either side.
        height: 16 + Math.max(30, textCol.implicitHeight)
        radius: Tokyo.pillRadius
        color: Tokyo.panelFill

        x: (1 - root.shown) * (root.width + 24)
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Critical notifications get a stripe down the leading edge: colour
        // alone does not survive a greyscale screenshot or a colour-blind eye.
        Rectangle {
            x: 1
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height - 12
            radius: 2
            color: root.accent
            visible: root.accent !== Tokyo.blue
        }

        NotifyIcon {
            x: 10
            y: 8
            size: 30
            source: root.n
            store: root.store
        }

        Column {
            id: textCol
            x: 48
            y: 8
            // `.x`, not `.left`: Item.left is a QQuickAnchorLine object, not a
            // number, so arithmetic on it goes NaN and every glyph disappears.
            width: dismiss.x - x - 6
            spacing: 1

            Text {
                width: parent.width
                text: root.n ? String(root.n.appName || "") : ""
                visible: text !== ""
                color: Tokyo.dim
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 9; letterSpacing: 0.6 }
            }
            Text {
                width: parent.width
                text: root.n ? String(root.n.summary || root.n.body || "") : ""
                textFormat: Text.PlainText
                color: root.accent === Tokyo.red ? Tokyo.red : Tokyo.fg
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
            }
            Text {
                width: parent.width
                visible: root.n !== null && root.n !== undefined
                         && String(root.n.body || "") !== ""
                         && String(root.n.body) !== String(root.n.summary)
                text: root.n ? String(root.n.body || "") : ""
                textFormat: Text.PlainText
                color: Tokyo.dim
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                font { family: Tokyo.fontFamily; pixelSize: 10 }
            }
        }

        Rectangle {
            id: dismiss
            anchors { right: parent.right; rightMargin: 4; top: parent.top; topMargin: 4 }
            width: 20; height: 20
            radius: 5
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "×"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 12 }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.leave(true)
            }
        }

        // The body, under the × and the stripe: a click means "do the default
        // thing", which is what the spec's default action is for.
        MouseArea {
            anchors {
                left: parent.left; leftMargin: 6
                right: dismiss.left; rightMargin: 4
                top: parent.top; topMargin: 4
                bottom: parent.bottom; bottomMargin: 4
            }
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.n === null || root.n === undefined) return
                for (const action of root.n.actions) {
                    if (action.identifier === "default") {
                        action.invoke()
                        break
                    }
                }
                root.leave(true)
            }
        }
    }

    Timer {
        id: life
        interval: root.timeout
        repeat: false
        onTriggered: root.leave(false)
    }

    Component.onCompleted: {
        root.shown = 0
        Qt.callLater(() => root.shown = 1)
        if (root.n === null || root.n === undefined) { root.leave(false); return }
        if (root.timeout > 0) life.start()
    }

    // A destroyed notification (the client closed or replaced it) nulls `n`.
    onNChanged: if (root.n === null || root.n === undefined) root.leave(false)

    Connections {
        target: root.n
        function onClosed() { root.leave(false) }
    }
}

