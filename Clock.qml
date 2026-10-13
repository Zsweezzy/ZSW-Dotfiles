// Clock.qml — the bar's centre pill: three virtual boxes of one width, the
// clock dead centre. The now-playing controls live in the left box, the clock
// face in the middle, the weather temperature in the right.
//
// The boxes are always present and always the same width — each is the widest
// of the three contents — and what belongs to a box is centred inside it. The
// pill therefore never resizes and nothing ever moves: a player appearing
// fills the left box, the reading settling fills the right one, and the clock
// stays exactly where it was. One pill, three rooms.
//
// Left-clicking it opens ClockFlyout, a popup that is anchored to the bar
// rather than to this widget — it opens centred at the top of the screen and
// hangs clear of the pill — so nothing here has to move, re-measure or hide
// when it does. The pill stays lit and on screen the whole time, which is why
// it can read as the thing that owns the clock even while the panel is up.
//
// Left-click opens the flyout, so the pill takes `hoverStyle` (it looks
// clickable). The media buttons sit inside the same pill but swallow their own
// clicks: a press lands on their MouseArea, not the Module's, so tapping
// pause or skip never opens the panel.
import QtQuick

Module {
    id: root

    fg: Tokyo.fg
    hoverStyle: true                       // it opens a flyout
    /// shared ClockFlyout (Bar.qml) — may be null in previews
    property var flyoutHost: null

    // Module's own label stays empty; the face draws the content.
    text: ""

    // The widget's clock. Owned here rather than by the face, and read by the
    // flyout as well (`ClockFlyout.clock`), so the pill's seconds and the
    // panel's seconds are the same Date rather than two Timers started at two
    // instants and free to sit a second apart against the wall clock.
    property var now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    implicitHeight: Tokyo.pillHeight
    // The whole content is the centred Row: its width already carries the hPad
    // on each side's worth, so the Row plus Module's own horizontal padding.
    implicitWidth: row.implicitWidth + hPad * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        // Three virtual boxes of one width, all present in every state: the
        // strip appears and disappears inside the left box, the reading inside
        // the right one, and the pill never changes size. Each box is the
        // widest of the three contents, so the clock sits exactly dead centre.
        readonly property real cellW: Math.max(
            strip.implicitWidth, face.contentW, weatherPill.contentW)

        // ---- left: the media strip ----
        Item {
            width: row.cellW
            height: Tokyo.pillHeight

            // pause, stationary art square, skip — the moment's essential
            // controls. The story (title, seek, shuffle, volume) is the flyout
            // card's.
            MediaPill {
                id: strip
                width: implicitWidth
                anchors.centerIn: parent
            }
        }

        // ---- middle: the clock ----
        Item {
            width: row.cellW
            height: Tokyo.pillHeight

            ClockFace {
                id: face
                anchors.centerIn: parent
                // The face's own metrics, not the live text: sized off
                // `contentW`, so the pill never resizes on the second. See
                // ClockFace.qml.
                width: face.contentW
                height: Tokyo.pillHeight
                // `hovered`, not `lit`: nothing borrows this pill's hover
                // state any more. The flyout is a separate surface on the far
                // side of the screen, so it never covers the pill and the
                // bar's MouseArea keeps hearing the pointer for as long as it
                // is really there.
                hovered: root.hovered
                now: root.now
            }
        }

        // ---- right: the weather ----
        Item {
            width: row.cellW
            height: Tokyo.pillHeight

            // Temperature only, no place name: the full story is the flyout
            // card's. Centred in its box, like everything else in the row.
            WeatherPill {
                id: weatherPill
                anchors.centerIn: parent
            }
        }
    }

    onClicked: button => {
        if (button === Qt.LeftButton && root.flyoutHost) root.flyoutHost.toggleFor(root)
    }
}