import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// App launcher, opened by Super+R through the bar's IPC handler.
//
// It is a layer surface in the bar's own process, not an island popup: an
// xdg_popup hangs off the bar's surface, which never holds keyboard focus, so
// a field inside it could not be typed into. It is mapped for the whole
// session and only its input region and keyboard grab turn on while open, so
// opening costs a frame instead of a process start and a layer fade-in.
// It still *looks* like an island panel — flush against the capsule's bottom
// edge, with the capsule widening into it (see shell.qml).
//
// `screen` must never change at runtime (see shell.qml): repointing a layer
// surface rebuilds it, and Hyprland then sends it no pointer input at all.
PanelWindow {
    id: root

    /// Shown (and holding the keyboard) while true. Owned by shell.qml: one
    /// of these lives on every monitor and only the focused one opens.
    property bool open: false
    signal dismissed()
    property string query: ""
    property int index: 0
    property var apps: DesktopEntries.applications.values
    /// Width the bar's capsule is drawing right now (see shell.qml). The card
    /// is never wider than it, so the two windows stay flush while rescaling.
    property real capsuleWidth: Tokyo.launcherWidth

    readonly property var matches: {
        const q = root.query.trim().toLowerCase();
        const seen = new Set();
        return root.apps
            .filter(a => a.name && !a.noDisplay && (q === ""
                || a.name.toLowerCase().includes(q)
                || (a.genericName || "").toLowerCase().includes(q)))
            .sort((a, b) => a.name.localeCompare(b.name))
            .filter(a => {
                if (seen.has(a.name)) return false;
                seen.add(a.name);
                return true;
            });
    }

    function launch() {
        const app = root.matches[root.index];
        if (app) app.execute();
        root.dismissed();
    }

    onOpenChanged: {
        if (!root.open) return;
        // Every open starts clean, like the fresh process this replaced.
        input.clear();
        root.index = 0;
        Qt.callLater(() => input.forceActiveFocus());
    }

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Zero-sized while closed: the surface stays mapped but lets every click
    // through to whatever is underneath. Full while open so a click outside
    // the card dismisses the launcher.
    mask: Region { item: inputArea }
    Item {
        id: inputArea
        x: 0
        y: 0
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    // Window scope, so the search field cannot swallow Escape.
    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.dismissed()
    }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        enabled: root.open
        onClicked: root.dismissed()
    }

    // The pill's shadow is drawn by the bar; this continues it along the
    // card. Clipped at the capsule's bottom edge — above the seam the bar's
    // own shadow is already there, and this window sits above the bar.
    Item {
        x: card.x - Tokyo.shadowBlur
        y: card.y
        width: card.width + Tokyo.shadowBlur * 2
        height: card.height + Tokyo.shadowBlur + Tokyo.shadowOffsetY
        clip: true
        visible: card.height > 1

        RectangularShadow {
            x: Tokyo.shadowBlur
            y: 0
            width: card.width
            height: card.height
            radius: Tokyo.islandPanelRadius
            // Square where it meets the capsule, like the card itself.
            topLeftRadius: 0
            topRightRadius: 0
            blur: Tokyo.shadowBlur
            offset: Qt.vector2d(0, Tokyo.shadowOffsetY)
            color: Tokyo.shadowColor
        }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // The capsule's bottom edge: island centre (barHeight/2 +
        // barShiftV - shadowPad/2) plus half its height.
        anchors.topMargin: Tokyo.barHeight
        width: Math.min(Tokyo.launcherWidth, root.capsuleWidth)
        // Unrolls down from the capsule on open and rolls back up on close.
        height: root.open ? body.implicitHeight + 32 : 0
        Behavior on height {
            NumberAnimation {
                duration: root.open ? Tokyo.expandDuration : Tokyo.collapseDuration
                easing.type: Easing.OutCubic
            }
        }
        radius: Tokyo.islandPanelRadius
        // Square at the top: the capsule above is the same width and meets
        // this edge, so the two read as one shape.
        topLeftRadius: 0
        topRightRadius: 0
        color: Tokyo.islandFill
        clip: true

        // Swallow clicks on the card's own padding, so only the backdrop
        // outside it dismisses the launcher.
        MouseArea { anchors.fill: parent }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: 16; rightMargin: 16; topMargin: 16 }
            spacing: 14
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Tokyo.expandDuration; easing.type: Easing.OutCubic }
            }
            // Fades in under the unrolling edge instead of popping at full
            // strength in a sliver of card.
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
                    id: label
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Apps"
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 11; bold: true; letterSpacing: 0.5 }
                }

                TextInput {
                    id: input
                    anchors.left: label.right
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
                        text: "Search apps…"
                        color: Tokyo.dim
                        font: input.font
                    }

                    onTextChanged: {
                        root.query = text;
                        root.index = 0;
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) {
                            root.index = Math.max(0, Math.min(root.index + 1, root.matches.length - 1));
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.index = Math.max(root.index - 1, 0);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launch();
                            event.accepted = true;
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
                    Behavior on color {
                        ColorAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        text: modelData.name
                        elide: Text.ElideRight
                        color: index === root.index ? Tokyo.fg : Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.index = index;
                            root.launch();
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
                text: "No apps"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 12 }
            }
        }
    }

    onIndexChanged: list.positionViewAtIndex(index, ListView.Contain)
}
