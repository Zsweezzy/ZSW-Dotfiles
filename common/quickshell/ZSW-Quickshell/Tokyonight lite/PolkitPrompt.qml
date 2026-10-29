import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

// The polkit authentication dialog. Replaces hyprpolkitagent: the password
// prompt is a card joined to the capsule instead of a separate GTK window, so
// `pkexec`, systemd reboot and anything else privileged ask where the shell
// already is. One agent per session: hyprpolkitagent must not be started.
PanelWindow {
    id: root

    /// The running authentication request, or null when nothing is pending.
    property var flow: null
    /// True only on the focused monitor: the prompt is a per-screen window,
    /// like the launcher, because a layer surface cannot be moved to another
    /// output at runtime (Hyprland stops sending it input after a rebuild).
    property bool open: false
    /// Width the bar's capsule is drawing right now (see shell.qml). The card
    /// is never wider than it, so the two windows stay flush while the capsule
    /// widens for the prompt.
    property real capsuleWidth: Tokyo.polkitWidth

    /// True while the card should be on screen.
    readonly property bool shown: root.open && root.flow !== null

    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-polkit"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive
                                            : WlrKeyboardFocus.None
    // Zero-sized while idle so every click passes through to the desktop;
    // full while a prompt is up so nothing behind it can be clicked.
    mask: Region { item: inputArea }

    Item {
        id: inputArea
        width: root.shown ? root.width : 0
        height: root.shown ? root.height : 0
    }

    onShownChanged: {
        if (!root.shown) return;
        // A cancelled attempt leaves its text in the field; a later prompt
        // must not start with someone else's masked password in it.
        password.text = "";
        Qt.callLater(() => card.focusInput());
    }

    function cancel() {
        if (root.flow) root.flow.cancelAuthenticationRequest()
    }

    // Escape cancels. Keys on the field rather than a window Shortcut:
    // QQuickShortcut's destructor segfaults this Qt build when the window dies
    // with a flow open (three core dumps on 2026-10-29). The field holds focus
    // whenever the card is up, so the key still arrives.

    // The pill's shadow is drawn by the bar; this continues it along the
    // card. Clipped at the capsule's bottom edge — above the seam the bar's
    // own shadow is already there, and this window sits above the bar.
    Item {
        x: card.x - Tokyo.shadowBlur
        y: card.y
        width: card.width + Tokyo.shadowBlur * 2
        height: card.height + Tokyo.shadowBlur + Tokyo.shadowOffsetY
        clip: true

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

        x: (root.width - width) / 2
        // Parked above the surface while closed: the card stays in the scene
        // graph, because an item that has never been rendered does not paint
        // when it is first shown. Moving it is a change the surface reports.
        y: root.shown ? Tokyo.barHeight : -card.height - 40
        // The capsule widens to this while the prompt is up, and its bottom
        // edge is square, so the two read as one shape.
        width: Math.min(Tokyo.polkitWidth, root.capsuleWidth)
        height: body.implicitHeight + Tokyo.panelPadV * 2
        radius: Tokyo.islandPanelRadius
        topLeftRadius: 0
        topRightRadius: 0
        color: Tokyo.islandFill

        function focusInput() {
            password.forceActiveFocus()
        }

        function submit() {
            if (!root.flow) return
            root.flow.submit(password.text)
            password.text = ""
            password.forceActiveFocus()
        }

        Column {
            id: body
            x: Tokyo.panelPadH
            y: Tokyo.panelPadV
            width: card.width - Tokyo.panelPadH * 2
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: "\uf023"
                    color: Tokyo.blue
                    font { family: Tokyo.fontFamily; pixelSize: 16 }
                }
                Text {
                    width: parent.width - 26
                    text: root.flow ? root.flow.message : ""
                    color: Tokyo.fg
                    wrapMode: Text.WordWrap
                    font { family: Tokyo.fontFamily; pixelSize: 12 }
                }
            }

            Text {
                width: parent.width
                visible: root.flow && root.flow.supplementaryMessage !== ""
                text: root.flow ? root.flow.supplementaryMessage : ""
                color: root.flow && root.flow.supplementaryIsError ? Tokyo.red : Tokyo.dim
                wrapMode: Text.WordWrap
                font { family: Tokyo.fontFamily; pixelSize: 11 }
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: Tokyo.pillRadius
                color: "transparent"
                border.width: 1
                border.color: password.activeFocus ? Tokyo.blue : Tokyo.paneEdge

                TextInput {
                    id: password
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Tokyo.fg
                    selectionColor: Tokyo.blue
                    selectedTextColor: Tokyo.islandFill
                    font { family: Tokyo.fontFamily; pixelSize: 12 }
                    onAccepted: card.submit()
                    Keys.onEscapePressed: root.cancel()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: root.flow && root.flow.inputPrompt !== ""
                              ? root.flow.inputPrompt : "Password"
                        color: Tokyo.dim
                        font { family: Tokyo.fontFamily; pixelSize: 12 }
                    }
                }
            }

            RowLayout {
                width: parent.width

                Text {
                    text: "Enter to authenticate · Esc to cancel"
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                }
                Item { Layout.fillWidth: true }

                Text {
                    text: "Cancel"
                    color: Tokyo.red
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: root.cancel()
                    }
                }
            }
        }
    }
}
