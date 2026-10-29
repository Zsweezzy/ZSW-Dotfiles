import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Clipboard history picker, opened by Super+V. Same window shape as the
// launcher (mapped for the session, input and keyboard only while open), but
// it floats: it is opened by a key, not by the capsule, so it is not attached
// to the bar's bottom edge.
PanelWindow {
    id: root

    /// Shown (and holding the keyboard) while true. Owned by shell.qml.
    property bool open: false
    signal dismissed()

    property string query: ""
    property int index: 0
    /// { id, text } entries, newest first, as cliphist stores them.
    property var entries: []

    readonly property var matches: {
        const q = root.query.trim().toLowerCase()
        if (q === "") return root.entries
        return root.entries.filter(e => e.text.toLowerCase().includes(q))
    }

    onOpenChanged: {
        if (!root.open) return
        root.query = ""
        root.index = 0
        listProcess.running = true
        Qt.callLater(() => input.forceActiveFocus())
    }

    function copy() {
        const entry = root.matches[root.index]
        if (!entry) return
        // Numeric id from cliphist's own output: nothing here is user text.
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + Number(entry.id) + " | wl-copy"])
        root.dismissed()
    }

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text === "") return
                const entries = []
                let current = null
                // An entry's text can contain newlines; only an id+tab starts
                // a new one.
                for (const line of this.text.split("\n")) {
                    const m = /^(\d+)\t(.*)$/.exec(line)
                    if (m) {
                        current = { id: m[1], text: m[2] }
                        entries.push(current)
                    } else if (current) {
                        current.text += "\n" + line
                    }
                }
                root.entries = entries
            }
        }
    }

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Zero-sized while closed: the surface stays mapped but lets every click
    // through. Full while open so a click outside the card dismisses.
    mask: Region { item: inputArea }
    Item {
        id: inputArea
        x: 0
        y: 0
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.dismissed()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.dismissed()
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokyo.barHeight
        width: 400
        height: root.open ? body.implicitHeight + Tokyo.panelPadV * 2 : 0
        Behavior on height {
            NumberAnimation {
                duration: root.open ? Tokyo.expandDuration : Tokyo.collapseDuration
                easing.type: Easing.OutCubic
            }
        }
        radius: Tokyo.popupRadius
        color: Tokyo.islandFill
        clip: true

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            x: Tokyo.panelPadH
            y: Tokyo.panelPadV
            width: card.width - Tokyo.panelPadH * 2
            spacing: 12
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Tokyo.expandDuration; easing.type: Easing.OutCubic }
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: Tokyo.pillRadius
                color: "transparent"
                border.width: 1
                border.color: Tokyo.paneEdge

                Text {
                    id: caption
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clip"
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 11; bold: true; letterSpacing: 0.5 }
                }
                TextInput {
                    id: input
                    anchors.left: caption.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    focus: root.open
                    color: Tokyo.fg
                    selectionColor: Tokyo.blue
                    selectedTextColor: Tokyo.islandFill
                    font { family: Tokyo.fontFamily; pixelSize: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    cursorDelegate: Rectangle { width: 1; color: Tokyo.blue }

                    Text {
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "Search clipboard…"
                        color: Tokyo.dim
                        font: input.font
                    }

                    onTextChanged: {
                        root.query = text
                        root.index = 0
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.index = Math.max(0, Math.min(root.index + 1, root.matches.length - 1))
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.index = Math.max(root.index - 1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.copy()
                            event.accepted = true
                        }
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(root.matches.length, 9) * 30
                model: root.matches
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onHeightChanged: positionViewAtIndex(root.index, ListView.Contain)

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 30
                    radius: 8
                    color: index === root.index ? Tokyo.panelFill : "transparent"
                    Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Text {
                        anchors { left: parent.left; right: parent.right
                                  leftMargin: 12; rightMargin: 12
                                  verticalCenter: parent.verticalCenter }
                        // One visual line per entry: stored text can hold
                        // newlines, and the row is a single-line preview.
                        text: modelData.text.replace(/\s+/g, " ").trim()
                        elide: Text.ElideRight
                        color: index === root.index ? Tokyo.fg : Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.index = index
                            root.copy()
                        }
                    }
                }
            }

            Text {
                visible: root.matches.length === 0
                width: parent.width
                height: visible ? 34 : 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Nothing copied yet"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 12 }
            }
        }
    }

    onIndexChanged: list.positionViewAtIndex(root.index, ListView.Contain)
}
