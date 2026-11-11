import QtQuick
import QtQuick.Layouts

Panel {
    id: root

    /// The Media module in the bar; the panel drives its player.
    property var mediaModule: null

    readonly property var player: root.mediaModule ? root.mediaModule.player : null
    readonly property real length: root.player ? root.player.length : 0
    readonly property bool seekable: root.player ? root.player.canSeek && root.length > 0 : false

    /// Seconds, refreshed from the player once a second while it plays. The
    /// player's own `position` is not a ticking property, so a local copy is
    /// what the bar can animate.
    property real pos: 0

    implicitWidth: 300

    Timer {
        interval: 1000
        repeat: true
        running: root.player !== null && root.player.isPlaying
        onTriggered: if (root.player) root.pos = root.player.position
    }

    Connections {
        target: root.player
        function onTrackChanged() { root.pos = 0 }
    }

    function clock(seconds) {
        if (!isFinite(seconds) || seconds < 0) seconds = 0
        const s = Math.floor(seconds % 60)
        return Math.floor(seconds / 60) + ":" + (s < 10 ? "0" : "") + s
    }

    RowLayout {
        width: parent.width
        spacing: 12

        Rectangle {
            width: 56
            height: 56
            radius: 8
            color: Tokyo.bgHighlight
            clip: true

            Image {
                id: art
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: !art.visible
                text: "\uf001"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 22 }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 3

            Text {
                width: parent.width
                text: root.player ? root.player.trackTitle : ""
                color: Tokyo.fg
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
            }
            Text {
                width: parent.width
                text: root.player ? root.player.trackArtist : ""
                color: Tokyo.dim
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 11 }
            }
            Text {
                width: parent.width
                text: root.player ? root.player.identity : ""
                color: Tokyo.islandDim
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 10 }
            }
        }
    }

    // Player picker. Only when there is a choice: one player is not a menu.
    // The chosen player survives the panel closing because `selected` lives on
    // the Media module in the capsule, not here.
    Row {
        id: picker
        width: parent.width
        spacing: 4
        visible: root.mediaModule !== null && root.mediaModule.allPlayers.length > 1

        readonly property int count: root.mediaModule ? root.mediaModule.allPlayers.length : 0

        Repeater {
            model: root.mediaModule ? root.mediaModule.allPlayers : []

            delegate: Rectangle {
                required property var modelData

                readonly property bool on: root.mediaModule.isCurrent(modelData)

                width: picker.count > 0
                       ? (picker.width - 4 * (picker.count - 1)) / picker.count : 0
                height: 20
                radius: 5
                color: on ? Tokyo.activeTint : "transparent"
                border.width: 1
                border.color: on ? Tokyo.magenta : Tokyo.paneEdge

                Text {
                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                    text: modelData.identity
                    color: on ? Tokyo.magenta : Tokyo.dim
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font { family: Tokyo.fontFamily; pixelSize: 9 }
                }

                MouseArea {
                    anchors.fill: parent
                    activeFocusOnTab: true
                    function activate() { root.mediaModule.pick(modelData) }
                    onClicked: activate()
                    FocusRing {}
                }
            }
        }
    }

    // Seek row. Hidden for streams, which have no length to scrub.
    Item {
        width: parent.width
        height: root.seekable ? 14 : 0
        visible: root.seekable

        Rectangle {
            id: seekTrack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Tokyo.bgHighlight
        }
        Rectangle {
            anchors { left: seekTrack.left; verticalCenter: seekTrack.verticalCenter }
            width: seekTrack.width * (root.length > 0 ? Math.min(1, root.pos / root.length) : 0)
            height: seekTrack.height
            radius: 2
            color: Tokyo.magenta
        }
        MouseArea {
            id: seekArea
            anchors.fill: parent
            activeFocusOnTab: true
            onPressed: m => {
                forceActiveFocus()
                seekTo(m.x / width)
            }
            Keys.onLeftPressed: seekBy(-5)
            Keys.onRightPressed: seekBy(5)
            function seekTo(f) {
                if (root.player && root.length > 0)
                    root.player.position = Math.max(0, Math.min(1, f)) * root.length
            }
            function seekBy(seconds) {
                if (!root.player) return
                root.player.position = Math.max(0, Math.min(root.length,
                                                            root.pos + seconds))
            }
        }
    }

    RowLayout {
        width: parent.width
        visible: root.seekable
        Text {
            text: root.clock(root.pos)
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: root.clock(root.length)
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 10 }
        }
    }

    RowLayout {
        width: parent.width
        spacing: 4

        Item { Layout.fillWidth: true }

        Text {
            text: "\uf048"
            color: root.player && root.player.canGoPrevious ? Tokyo.fg : Tokyo.islandDim
            font { family: Tokyo.fontFamily; pixelSize: 16 }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                activeFocusOnTab: true
                function activate() {
                    if (root.player && root.player.canGoPrevious) root.player.previous()
                }
                onClicked: activate()
                FocusRing {}
            }
        }

        Text {
            text: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
            color: Tokyo.magenta
            font { family: Tokyo.fontFamily; pixelSize: 20 }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                activeFocusOnTab: true
                function activate() {
                    if (root.player && root.player.canTogglePlaying)
                        root.player.togglePlaying()
                }
                onClicked: activate()
                FocusRing {}
            }
        }

        Text {
            text: "\uf051"
            color: root.player && root.player.canGoNext ? Tokyo.fg : Tokyo.islandDim
            font { family: Tokyo.fontFamily; pixelSize: 16 }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                activeFocusOnTab: true
                function activate() {
                    if (root.player && root.player.canGoNext) root.player.next()
                }
                onClicked: activate()
                FocusRing {}
            }
        }

        Item { Layout.fillWidth: true }
    }
}
