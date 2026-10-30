// NotificationRow.qml — one history entry, inside a group or on its own.
//
// Split out of NotificationsPanel so the group header and the row can both
// live in the same scrolling list: a group is a card of rows, and a row is
// this item. `showApp` is off inside a group, where the header already says
// which app it is.
import QtQuick
import Quickshell

Item {
    id: root

    required property var entry
    property var store: null
    property bool showApp: true

    implicitHeight: root.hasLiveActions ? 58 : 48

    readonly property bool hasLiveActions: root.entry.live !== null
        && root.entry.live !== undefined
        && root.entry.live.actions !== undefined
        && root.entry.live.actions.length > 0

    // The row's own focus ring: the launch area is only part of the height (the
    // action buttons take the rest), so the ring belongs to the whole card
    // rather than to the click target.
    FocusRing { visible: rowArea.activeFocus }

    Rectangle {
        anchors.fill: parent
        radius: Tokyo.pillRadius
        color: Tokyo.panelFill
        border.color: Tokyo.paneEdge
        border.width: 1
    }

    NotifyIcon {
        id: icon
        anchors { left: parent.left; leftMargin: 6
                  verticalCenter: parent.verticalCenter }
        size: 32
        // The live object when there is one, the record otherwise — NotifyIcon
        // reads the same field names off both.
        source: root.entry.live !== null && root.entry.live !== undefined
                ? root.entry.live : root.entry
        store: root.store
    }

    Column {
        anchors {
            left: icon.right; leftMargin: 10
            right: dismiss.left; rightMargin: 6
            top: parent.top; topMargin: 6
        }
        spacing: 2

        Item {
            width: parent.width
            height: 12
            visible: root.showApp

            Text {
                anchors { left: parent.left; right: time.left
                          rightMargin: 6
                          verticalCenter: parent.verticalCenter }
                text: root.entry.app
                color: Tokyo.dim
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 9
                       letterSpacing: 0.8 }
            }
            Text {
                id: time
                anchors { right: parent.right
                          verticalCenter: parent.verticalCenter }
                text: root.ago(root.entry.time)
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 9 }
            }
        }
        Text {
            width: parent.width
            text: root.entry.summary
            textFormat: Text.PlainText
            color: root.entry.urgency === 2 ? Tokyo.red : Tokyo.fg
            elide: Text.ElideRight
            font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
        }
        Text {
            width: parent.width
            visible: String(root.entry.body || "") !== ""
            text: root.entry.body
            textFormat: Text.PlainText
            color: Tokyo.dim
            elide: Text.ElideRight
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }
    }

    // ---------- the row's own actions ----------
    // Only while the notification is still live. Once the daemon has let go of
    // it the action cannot be delivered to anyone, and a button that silently
    // does nothing is worse than no button.
    Flow {
        id: acts
        anchors { left: icon.right; leftMargin: 10
                  bottom: parent.bottom; bottomMargin: 4 }
        spacing: 4
        visible: root.hasLiveActions
        height: visible ? 18 : 0

        Repeater {
            model: root.hasLiveActions ? root.entry.live.actions : []
            delegate: Rectangle {
                required property var modelData
                width: aText.implicitWidth + 12
                height: 18
                radius: 5
                color: Qt.rgba(0, 0, 0, 0.2)
                border.color: Tokyo.paneEdge
                border.width: 1

                Text {
                    id: aText
                    anchors.centerIn: parent
                    text: modelData.text
                    color: Tokyo.fg
                    font { family: Tokyo.fontFamily; pixelSize: 9 }
                }
                MouseArea {
                    anchors.fill: parent
                    activeFocusOnTab: true
                    function activate() {
                        modelData.invoke()
                        if (root.store !== null) root.store.dismiss(root.entry)
                    }
                    onClicked: activate()
                    FocusRing {}
                }
            }
        }
    }

    // ---------- dismiss ----------
    Rectangle {
        id: dismiss
        anchors { right: parent.right; rightMargin: 4
                  verticalCenter: parent.verticalCenter }
        width: 20
        height: 20
        radius: 5
        // Always there, not on hover: a delete you have to find is a delete you
        // do not use.
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "×"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 13 }
        }
        MouseArea {
            anchors.fill: parent
            activeFocusOnTab: true
            function activate() {
                if (root.store !== null) root.store.dismiss(root.entry)
            }
            onClicked: activate()
            FocusRing {}
        }
    }

    MouseArea {
        id: rowArea
        anchors {
            left: parent.left; leftMargin: 4
            right: acts.visible ? acts.left : dismiss.left
            top: parent.top
            bottom: acts.visible ? acts.top : parent.bottom
        }
        activeFocusOnTab: true
        function activate() { root.launch(root.entry) }
        onClicked: activate()
    }

    /// Open a notification's app. The live object carries the client's id, which
    /// is what `gtk-launch` wants; the record's app is the fallback for a
    /// notification read back off disk.
    function launch(entry) {
        const id = entry.desktopEntry !== "" ? entry.desktopEntry
                   : String(entry.app || "").toLowerCase().replace(/\s+/g, "-")
        if (id === "") return
        Quickshell.execDetached(["gtk-launch", id])
    }

    /// "4m" / "2h" / "3d". Recomputed when the row is built rather than stored,
    /// so a notification read on Tuesday is not labelled with Sunday's
    /// arithmetic.
    function ago(t) {
        const s = Math.max(0, Math.floor((Date.now() - t) / 1000))
        if (s < 60) return s + "s"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }
}
