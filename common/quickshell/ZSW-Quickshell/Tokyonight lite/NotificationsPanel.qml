// NotificationsPanel.qml — the notification centre, as an island flyout.
//
// The list is the history the store keeps, not the notifications the daemon is
// currently holding. Those are different things and the difference is the whole
// point of a centre: a toast has gone by the time you get to it, and a
// notification that is still resident because nothing acted on it is a bug
// report, not a record.
//
// Every row can still be acted on, because the store keeps the daemon's live
// object alongside the record for as long as it exists. When it does not — the
// notification expired, or it came back off disk — the row simply offers no
// action buttons rather than showing one that does nothing.
import QtQuick
import Quickshell

Panel {
    id: root

    /// the shell-wide store (NotificationStore.qml)
    property var store: null

    /// How many rows the list shows before it scrolls. A centre is for
    /// skimming, not for reading four hundred of them.
    readonly property int visibleRows: 8
    readonly property real rowH: 62

    implicitWidth: 380

    // Opening the centre is the act of reading it. Anything less makes the
    // badge a thing you have to dismiss separately, and a badge you have to
    // dismiss is a badge you learn to ignore.
    //
    // `centreOpen` is also what stops toasts from covering the panel: this
    // panel only exists while its flyout is open, so its lifetime is the flag.
    Component.onCompleted: {
        if (root.store === null) return
        root.store.centreOpen = true
        root.store.markAllRead()
    }
    Component.onDestruction: if (root.store !== null) root.store.centreOpen = false

    Item {
        width: parent.width
        height: 22

        Text {
            anchors { left: parent.left; leftMargin: 4
                      verticalCenter: parent.verticalCenter }
            text: "NOTIFICATIONS"
            color: Tokyo.blue
            font { family: Tokyo.fontFamily; pixelSize: 10
                   bold: true; letterSpacing: 1.5 }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 10

            Rectangle {
                width: dndText.implicitWidth + 14
                height: 18
                radius: Tokyo.pillRadius
                color: root.store !== null && root.store.dnd
                       ? Tokyo.activeTint : "transparent"
                border.width: 1
                border.color: root.store !== null && root.store.dnd
                              ? Tokyo.cyan : Tokyo.paneEdge

                Text {
                    id: dndText
                    anchors.centerIn: parent
                    text: "DND"
                    color: root.store !== null && root.store.dnd
                           ? Tokyo.cyan : Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 9; bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    activeFocusOnTab: true
                    function activate() {
                        if (root.store !== null) root.store.dnd = !root.store.dnd
                    }
                    onClicked: activate()
                    FocusRing {}
                }
            }

            Text {
                id: clearText
                anchors.verticalCenter: parent.verticalCenter
                text: "CLEAR ALL"
                color: root.store !== null && root.store.entries.length > 0
                       ? Tokyo.dim : Tokyo.bgHighlight
                font { family: Tokyo.fontFamily; pixelSize: 9
                       bold: true; letterSpacing: 1 }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    activeFocusOnTab: true
                    function activate() {
                        if (root.store !== null) root.store.clearAll()
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
        color: Tokyo.bgHighlight
    }

    ListView {
        id: list
        width: parent.width
        height: root.store === null || root.store.entries.length === 0
                ? 0
                : Math.min(root.store.entries.length, root.visibleRows) * root.rowH
        clip: true
        spacing: 4
        // Newest at the top, and the top is where the eye already is.
        model: root.store !== null ? root.store.entries : []
        boundsBehavior: Flickable.StopAtBounds

        // A delete leaves rather than blinking out: the row slides off to the
        // left and the ones below close the gap behind it. Both motions are the
        // ListView's own, so `dismiss()` still just drops the entry.
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        remove: Transition {
            NumberAnimation {
                properties: "x"
                to: -list.width
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                properties: "opacity"
                to: 0
                duration: 140
            }
        }

        delegate: Rectangle {
            id: entry
            required property var modelData
            required property int index

            width: list.width
            height: root.rowH - 4
            radius: Tokyo.pillRadius
            color: Tokyo.panelFill
            border.color: Tokyo.paneEdge
            border.width: 1

            // The row's own focus ring: the launch area is only part of the
            // height (the action buttons take the rest), so the ring belongs to
            // the whole card rather than to the click target.
            FocusRing { visible: rowArea.activeFocus }

            NotifyIcon {
                id: icon
                anchors { left: parent.left; leftMargin: 6
                          verticalCenter: parent.verticalCenter }
                size: 36
                // The live object when there is one, the record otherwise —
                // NotifyIcon reads the same field names off both.
                source: modelData.live !== null && modelData.live !== undefined
                        ? modelData.live : modelData
                store: root.store
            }

            Column {
                anchors {
                    left: icon.right; leftMargin: 10
                    right: dismiss.left; rightMargin: 6
                    top: parent.top; topMargin: 8
                }
                spacing: 2

                Item {
                    width: parent.width
                    height: 12

                    Text {
                        anchors { left: parent.left; right: time.left
                                  rightMargin: 6
                                  verticalCenter: parent.verticalCenter }
                        text: modelData.app
                        color: Tokyo.dim
                        elide: Text.ElideRight
                        font { family: Tokyo.fontFamily; pixelSize: 9
                               letterSpacing: 0.8 }
                    }
                    Text {
                        id: time
                        anchors { right: parent.right
                                  verticalCenter: parent.verticalCenter }
                        text: root.ago(modelData.time)
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 9 }
                    }
                }
                Text {
                    width: parent.width
                    text: modelData.summary
                    color: modelData.urgency === 2 ? Tokyo.red : Tokyo.fg
                    elide: Text.ElideRight
                    font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
                }
                Text {
                    width: parent.width
                    visible: String(modelData.body || "") !== ""
                    text: modelData.body
                    color: Tokyo.dim
                    elide: Text.ElideRight
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                }
            }

            // ---------- the row's own actions ----------
            // Only while the notification is still live. Once the daemon has
            // let go of it the action cannot be delivered to anyone, and a
            // button that silently does nothing is worse than no button.
            Flow {
                id: acts
                anchors { left: icon.right; leftMargin: 10
                          bottom: parent.bottom; bottomMargin: 4 }
                spacing: 4
                visible: entry.hasLiveActions
                height: visible ? 18 : 0

                Repeater {
                    model: entry.hasLiveActions ? modelData.live.actions : []
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
                                if (root.store !== null)
                                    root.store.dismiss(entry.modelData)
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
                // Always there, not on hover: a delete you have to find is a
                // delete you do not use.
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
                        if (root.store !== null)
                            root.store.dismiss(entry.modelData)
                    }
                    onClicked: activate()
                    FocusRing {}
                }
            }

            readonly property bool hasLiveActions: modelData.live !== null
                && modelData.live !== undefined
                && modelData.live.actions !== undefined
                && modelData.live.actions.length > 0

            MouseArea {
                id: rowArea
                anchors {
                    left: parent.left; leftMargin: 4
                    right: acts.visible ? acts.left : dismiss.left
                    top: parent.top
                    bottom: acts.visible ? acts.top : parent.bottom
                }
                activeFocusOnTab: true
                function activate() { root.launch(entry.modelData) }
                onClicked: activate()
            }
        }
    }

    Text {
        width: parent.width
        visible: root.store === null || root.store.entries.length === 0
        // Invisible does not mean zero-height inside a Column; without this the
        // empty state's line is reserved under a list that has rows in it.
        height: visible ? implicitHeight : 0
        text: "No Notifications"
        color: Tokyo.dim
        font { family: Tokyo.fontFamily; pixelSize: 10 }
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

    /// "4m" / "2h" / "3d". Recomputed on open rather than stored, so a
    /// notification read on Tuesday is not labelled with Sunday's arithmetic.
    function ago(t) {
        const s = Math.max(0, Math.floor((Date.now() - t) / 1000))
        if (s < 60) return s + "s"
        if (s < 3600) return Math.floor(s / 60) + "m"
        if (s < 86400) return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }
}
