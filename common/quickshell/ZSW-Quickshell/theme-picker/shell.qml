import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// Theme picker: a card that drops out of the bar's capsule at top centre, with
// a row of theme cards showing each theme's wallpaper and palette colors, then
// an "+" card that adds a wallpaper theme. Reads everything from
// `theme list --json`; adding and deleting go back through `theme wallpaper`.
ShellRoot {
    id: root
    property var palette: ({ bg: "#1a1a1a", surface: "#2a2a2a", fg: "#e6e6e6", accent: "#d0d0d0", island: "#151515", edge: "#3a3a3a", dim: "#8c8c8c" })
    property var themes: []
    property int index: 0
    property string currentSlug: ""

    readonly property int cardW: 190
    readonly property int cardH: 156
    readonly property int gap: 12
    readonly property int pad: 20
    // Three cards are always on screen (the two named themes plus "+"); more
    // themes scroll. Fixed so the capsule above, which widens to this width,
    // keeps an exact seam with the card's square top edge.
    readonly property int visibleCards: 3
    readonly property int panelW: root.cardW * root.visibleCards + root.gap * (root.visibleCards - 1) + root.pad * 2
    /// The "+" card sits one past the last theme.
    readonly property int addIndex: root.themes.length

    function syncIndex() {
        const i = root.themes.findIndex(t => t.slug === root.currentSlug);
        if (i >= 0) root.index = i;
    }

    function choose(i) {
        if (i === root.addIndex) { fileDialog.running = true; return; }
        if (!root.themes[i]) return;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/theme", "set", root.themes[i].slug]);
        Qt.quit();
    }

    function removeTheme(i) {
        const t = root.themes[i];
        if (!t || t.kind !== "wallpaper") return;
        deleteTheme.command = [Quickshell.env("HOME") + "/.local/bin/theme", "wallpaper", "rm", t.slug];
        deleteTheme.running = true;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/theme/current"
        onLoaded: root.currentSlug = text().trim()
    }

    onCurrentSlugChanged: syncIndex()

    FileView {
        path: Quickshell.env("HOME") + "/.config/themes/current.json"
        onLoaded: {
            try {
                const p = JSON.parse(text());
                if (p.bg) root.palette = p;
            } catch (e) {}
        }
    }

    Process {
        id: listThemes
        command: [Quickshell.env("HOME") + "/.local/bin/theme", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    root.themes = Array.isArray(list) ? list : [];
                } catch (e) {
                    root.themes = [];
                }
                root.syncIndex();
            }
        }
    }

    // The file dialog, then `theme wallpaper add <path>`; the list reloads
    // afterwards, so the new card appears without reopening the picker.
    Process {
        id: fileDialog
        command: ["kdialog", "--getopenfilename", Quickshell.env("HOME") + "/Pictures",
                  "Images (*.png *.jpg *.jpeg *.webp)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (!path) return;
                addTheme.command = [Quickshell.env("HOME") + "/.local/bin/theme", "wallpaper", "add", path];
                addTheme.running = true;
            }
        }
    }

    Process {
        id: addTheme
        stdout: StdioCollector { onStreamFinished: listThemes.running = true }
        stderr: StdioCollector {}
    }

    Process {
        id: deleteTheme
        stdout: StdioCollector { onStreamFinished: listThemes.running = true }
        stderr: StdioCollector {}
    }

    PanelWindow {
        anchors { top: true; left: true; right: true; bottom: true }
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-theme-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        }

        Rectangle {
            id: panel
            visible: root.themes.length > 0
            width: root.panelW
            height: 240
            // Drop out of the bar's capsule: its bottom edge is at y=34, and
            // the bar squares the pill's bottom corners while we are open.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 34
            radius: 20
            // Square top joins the widened capsule above; bottom stays rounded.
            topLeftRadius: 0
            topRightRadius: 0
            color: root.palette.island
            // No outer border: the capsule above is the same fill, so a stroke
            // would draw a seam right through the join.
            border.width: 0
            opacity: 0

            // Fade only: the capsule is already the card's full width when the
            // layer maps, and a scale would pull the square top out of line.
            NumberAnimation {
                id: openAnim
                target: panel
                property: "opacity"
                to: 1
                duration: 120
                easing.type: Easing.OutCubic
            }

            onVisibleChanged: {
                if (visible) {
                    panel.opacity = 0;
                    openAnim.restart();
                }
            }

            // Swallow clicks so only the transparent catcher around the card
            // closes the picker.
            MouseArea { anchors.fill: parent }

            Component.onCompleted: if (visible) openAnim.restart()

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: root.pad
                anchors.topMargin: 16
                text: "Theme"
                color: root.palette.fg
                opacity: 0.55
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 12
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: root.pad
                anchors.topMargin: 17
                text: root.themes.length + (root.themes.length === 1 ? " theme" : " themes")
                color: root.palette.fg
                opacity: 0.35
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 11
            }

            Flickable {
                id: scroller
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 44
                width: root.panelW - root.pad * 2
                height: root.cardH
                contentWidth: row.implicitWidth
                contentHeight: height
                clip: true
                interactive: contentWidth > width
                boundsBehavior: Flickable.StopAtBounds

                // Centre the row while it fits, scroll it once it does not.
                function reveal(i) {
                    const x = i * (root.cardW + root.gap);
                    if (x < contentX) contentX = x;
                    else if (x + root.cardW > contentX + width) contentX = x + root.cardW - width;
                }

                Row {
                    id: row
                    x: Math.max(0, (scroller.width - implicitWidth) / 2)
                    spacing: root.gap

                    Repeater {
                        model: root.themes
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            width: root.cardW
                            height: root.cardH
                            radius: 16
                            color: index === root.index
                                ? root.palette.surface
                                : Qt.rgba(1, 1, 1, 0.04)
                            border.width: index === root.index ? 2 : 1
                            border.color: index === root.index
                                ? root.palette.accent
                                : Qt.rgba(1, 1, 1, 0.08)

                            // Little tab on the active card, like the island picker.
                            Rectangle {
                                visible: card.index === root.index
                                width: 10
                                height: 10
                                radius: 5
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -5
                                color: root.palette.island
                                border.width: 2
                                border.color: root.palette.accent
                            }

                            ClippingRectangle {
                                id: preview
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 12
                                width: parent.width - 24
                                height: 82
                                radius: 10
                                color: root.palette.surface

                                Image {
                                    anchors.fill: parent
                                    source: modelData.wallpaper ? "file://" + modelData.wallpaper : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: preview.bottom
                                anchors.topMargin: 12
                                spacing: 5

                                Repeater {
                                    model: modelData.swatches
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                text: modelData.name
                                color: index === root.index ? root.palette.accent : root.palette.fg
                                font.family: "JetBrains Mono Nerd Font"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.index = index
                                onClicked: root.choose(index)
                            }
                        }
                    }

                    // "+" card: pick an image, derive a theme from it.
                    Rectangle {
                        id: addCard
                        width: root.cardW
                        height: root.cardH
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.width: root.index === root.addIndex ? 2 : 1
                        border.color: root.index === root.addIndex
                            ? root.palette.accent
                            : Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: root.index === root.addIndex ? root.palette.accent : root.palette.fg
                            opacity: root.index === root.addIndex ? 1 : 0.5
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 34
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            text: "Wallpaper theme"
                            color: root.index === root.addIndex ? root.palette.accent : root.palette.fg
                            opacity: 0.7
                            font.family: "JetBrains Mono Nerd Font"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.index = root.addIndex
                            onClicked: root.choose(root.addIndex)
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.pad
                anchors.bottomMargin: 14
                text: root.themes[root.index]?.kind === "wallpaper" ? "Enter to apply · Delete to remove" : "Enter to apply"
                color: root.palette.fg
                opacity: 0.3
                font.family: "JetBrains Mono Nerd Font"
                font.pixelSize: 11
            }
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    Qt.quit();
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.index = Math.min(root.index + 1, root.addIndex);
                    scroller.reveal(root.index);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.index = Math.max(root.index - 1, 0);
                    scroller.reveal(root.index);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete) {
                    root.removeTheme(root.index);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.choose(root.index);
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()
        }
    }
}
