// NotificationsPanel.qml — the notification centre, as an island flyout.
//
// The list is the history the store keeps, not the notifications the daemon is
// currently holding. Those are different things and the difference is the whole
// point of a centre: a toast has gone by the time you get to it, and a
// notification that is still resident because nothing acted on it is a bug
// report, not a record.
//
// Rows are grouped by app (Settings.groupNotifications). A group is a view of
// the flat history, so the log and the per-entry actions are untouched by the
// grouping; the header carries the app-level actions — mute and clear — that
// swaync's groups have.
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

    // The model is groups when grouping is on, and one-entry groups when it is
    // off, so the delegate is the same either way. `single` is what hides the
    // header and lets the row be the card.
    readonly property var model: {
        if (root.store === null) return []
        if (Settings.groupNotifications) return root.store.groups
        return root.store.entries.map(e => ({
            app: String(e.app || ""), entries: [e], single: true,
        }))
    }

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
                color: Settings.dnd ? Tokyo.activeTint : "transparent"
                border.width: 1
                border.color: Settings.dnd ? Tokyo.cyan : Tokyo.paneEdge

                Text {
                    id: dndText
                    anchors.centerIn: parent
                    text: "DND"
                    color: Settings.dnd ? Tokyo.cyan : Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 9; bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    activeFocusOnTab: true
                    function activate() { Settings.dnd = !Settings.dnd }
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
        // Variable-height groups, capped at what a centre should show at once.
        // contentHeight lands after the first layout, which is why this is not
        // a count of rows any more.
        height: Math.min(contentHeight, root.visibleRows * root.rowH)
        clip: true
        spacing: 4
        // Newest at the top, and the top is where the eye already is.
        model: root.model
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
            id: group
            required property var modelData
            required property int index

            readonly property bool single: modelData.single === true
            readonly property bool showHeader: !group.single
            /// A stack of one is a row, not a group; a stack of many opens at
            /// three and the header toggles the rest.
            property bool expanded: false
            readonly property int shown: group.expanded
                                            ? modelData.entries.length
                                            : Math.min(3, modelData.entries.length)

            width: list.width
            height: (group.showHeader ? 24 : 0) + rows.implicitHeight
            radius: Tokyo.pillRadius
            color: group.showHeader ? Tokyo.boxFill : "transparent"
            border.width: group.showHeader ? 1 : 0
            border.color: Tokyo.paneEdge
            clip: true

            // ---------- app header ----------
            Item {
                id: header
                visible: group.showHeader
                width: parent.width
                height: 24

                Text {
                    anchors { left: parent.left; leftMargin: 8
                              right: groupCount.left; rightMargin: 6
                              verticalCenter: parent.verticalCenter }
                    text: group.modelData.app
                    color: Tokyo.fg
                    elide: Text.ElideRight
                    font { family: Tokyo.fontFamily; pixelSize: 10; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        activeFocusOnTab: true
                        function activate() {
                            if (group.modelData.entries.length > 3)
                                group.expanded = !group.expanded
                        }
                        onClicked: activate()
                        FocusRing {}
                    }
                }

                Text {
                    id: groupCount
                    anchors { right: muteText.left; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    text: String(group.modelData.entries.length)
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 9 }
                }

                Text {
                    id: muteText
                    anchors { right: clearGroup.left; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    text: Settings.isMuted(group.modelData.app) ? "MUTED" : "MUTE"
                    color: Settings.isMuted(group.modelData.app) ? Tokyo.cyan : Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 9; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        activeFocusOnTab: true
                        function activate() {
                            Settings.toggleMuted(group.modelData.app)
                        }
                        onClicked: activate()
                        FocusRing {}
                    }
                }

                Text {
                    id: clearGroup
                    anchors { right: parent.right; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    text: "×"
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 13 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        activeFocusOnTab: true
                        function activate() {
                            if (root.store !== null)
                                root.store.dismissApp(group.modelData.app)
                        }
                        onClicked: activate()
                        FocusRing {}
                    }
                }
            }

            Column {
                id: rows
                y: group.showHeader ? 24 : 0
                width: parent.width
                spacing: 4

                Repeater {
                    model: group.modelData.entries.slice(0, group.shown)
                    delegate: NotificationRow {
                        required property var modelData
                        width: rows.width
                        entry: modelData
                        store: root.store
                        showApp: false
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: root.model.length === 0
        // Invisible does not mean zero-height inside a Column; without this the
        // empty state's line is reserved under a list that has rows in it.
        height: visible ? implicitHeight : 0
        text: "No Notifications"
        color: Tokyo.dim
        font { family: Tokyo.fontFamily; pixelSize: 10 }
    }
}
