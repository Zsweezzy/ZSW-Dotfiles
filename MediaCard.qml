// MediaCard.qml — the NOW PLAYING card in the clock flyout.
//
// A full QuadCell, so ClockFlyout.qml only has to place it: the frame, the
// title row and the source tag live here, and the body is everything the bar
// pill cannot say — the big grey record, the track, a seek bar, the transport,
// shuffle and loop, and volume.
//
// Everything is a function of the one `Media` singleton, which is why this card
// and the bar pill can never disagree about the track. Idle is a state, not an
// absence: the card stays put and says "Nothing playing", so the flyout's shape
// does not jump the moment a song ends.
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts

QuadCell {
    id: root

    title: "NOW PLAYING"
    accent: Tokyo.green

    // The source is read off the MPRIS bus identity, so it is the only honest
    // answer to "is this Spotify or a YouTube tab?". Shown as the card's tag,
    // and coloured the way the source's own brand would be — which is also what
    // makes "why is the shuffle button dead?" answer itself.
    readonly property color sourceColor:
        Media.source === "spotify" ? Tokyo.green
        : Media.source === "youtube" ? Tokyo.red
        : Media.source === "browser" ? Tokyo.orange
        : Tokyo.dim

    headerExtra: Text {
        Layout.alignment: Qt.AlignVCenter
        text: Media.sourceLabel
        color: root.sourceColor
        font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
    }

    /// seconds -> "m:ss"
    function fmt(s) {
        const t = (isFinite(s) && s > 0) ? Math.floor(s) : 0
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0")
    }

    // A slider in the same shape as AudioFlyout's: flat track, filled portion,
    // round handle. Controls-internal geometry is what `availableWidth` /
    // `leftPadding` are, exactly as that file reads it.
    component MediaSlider: Controls.Slider {
        id: sl
        property color accent: Tokyo.green
        height: 22
        from: 0
        to: 1
        background: Rectangle {
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: sl.availableWidth
            height: 4
            radius: 2
            color: Tokyo.bgHighlight
            Rectangle {
                width: sl.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: sl.accent
            }
        }
        handle: Rectangle {
            x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: 12
            height: 12
            radius: 6
            color: sl.pressed ? Tokyo.fg : Tokyo.pink
            border.color: Tokyo.bgDark
            border.width: 1
        }
    }

    // ---------- body ----------
    // No positioner here that nests inside another: the outer Column holds two
    // mutually-exclusive blocks, and each block is a Column of its own — a
    // plain column of plain items, which Qt polishes in one pass.
    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 6

        // ---------- idle ----------
        Text {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: !Media.active
            text: "Nothing playing"
            color: Tokyo.dim
            topPadding: 40
            horizontalAlignment: Text.AlignHCenter
            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize }
        }

        // ---------- active ----------
        Column {
            width: parent.width
            spacing: 6
            visible: Media.active
            height: visible ? implicitHeight : 0

            Item {
                width: parent.width
                height: 100
                Record {
                    anchors.centerIn: parent
                    width: 100
                    height: 100
                    artSource: Media.artSource
                    labelColor: Tokyo.green
                    spinning: Media.isPlaying
                }
            }

            Text {
                width: parent.width
                text: Media.title
                color: Tokyo.fg
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                font { family: Tokyo.fontFamily; pixelSize: 14; bold: true }
            }
            Text {
                width: parent.width
                height: text !== "" ? implicitHeight : 0
                visible: text !== ""
                text: Media.artist
                color: Tokyo.dim
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 12 }
            }
            Text {
                width: parent.width
                height: text !== "" ? implicitHeight : 0
                visible: text !== ""
                text: Media.album
                color: Tokyo.trayGlyph
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font { family: Tokyo.fontFamily; pixelSize: 10 }
            }

            MediaSlider {
                id: seek
                width: parent.width
                accent: Tokyo.green
                // A deck that cannot seek, or does not report a length, gets a
                // dead bar rather than one that pretends to move.
                enabled: Media.canSeek && Media.positionSupported && Media.length > 0
                to: Math.max(1, Media.length)
                value: Media.position
                onMoved: Media.seekTo(value)
            }

            Item {
                width: parent.width
                height: 14
                Text {
                    anchors.left: parent.left
                    text: root.fmt(Media.position)
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                }
                Text {
                    anchors.right: parent.right
                    text: Media.length > 0 ? root.fmt(Media.length) : "--:--"
                    color: Tokyo.dim
                    font { family: Tokyo.fontFamily; pixelSize: 10 }
                }
            }

            // ---------- transport ----------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                PillButton {
                    glyph: "\uF048"          // back
                    accent: Tokyo.blue
                    enabled: Media.canPrevious
                    onClicked: Media.previous()
                }
                PillButton {
                    glyph: Media.isPlaying ? "\uF04C" : "\uF04B"   // pause / play
                    accent: Tokyo.green
                    enabled: Media.canToggle
                    onClicked: Media.togglePlaying()
                }
                PillButton {
                    glyph: "\uF051"          // forward
                    accent: Tokyo.blue
                    enabled: Media.canNext
                    onClicked: Media.next()
                }
                PillButton {
                    glyph: "\uF074"          // shuffle
                    accent: Media.shuffled ? Tokyo.green : Tokyo.dim
                    enabled: Media.shuffleAvailable
                    onClicked: Media.toggleShuffle()
                }
                PillButton {
                    // repeat, with a "1" for the single-track state
                    glyph: Media.loopTrack ? "\uF01E1" : "\uF01E"
                    accent: Media.looping ? Tokyo.green : Tokyo.dim
                    enabled: Media.loopSupported
                    onClicked: Media.cycleLoop()
                }
            }

            // ---------- volume ----------
            Item {
                width: parent.width
                height: 22
                Text {
                    id: volGlyph
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 14
                    text: "\uF028"
                    color: Media.volumeSupported ? Tokyo.dim : Tokyo.bgHighlight
                    font { family: Tokyo.fontFamily; pixelSize: 11 }
                }
                MediaSlider {
                    anchors {
                        left: volGlyph.right; leftMargin: 6
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    accent: Tokyo.magenta
                    enabled: Media.volumeSupported
                    to: 1
                    value: Media.volume
                    onMoved: Media.setVolume(value)
                }
            }
        }
    }
}
