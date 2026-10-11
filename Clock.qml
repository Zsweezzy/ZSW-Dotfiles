// Clock.qml — the bar's centre pill: the clock face with the now-playing
// controls fused into its left edge while something is playing.
//
// One pill, not two. When a player is active, a stationary square of the art
// with pause/play and skip on either side (`MediaPill`) leads the clock face,
// and an equal-width mirror behind it keeps the face dead centre no matter how
// wide the strip is. When nothing plays, the strip collapses to nothing and
// the pill is exactly the clock it always was.
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
        spacing: 14   // +4 via the mirror too, so the face stays centred

        // pause, stationary art square, skip — the moment's essential controls.
        // The story (title, seek, shuffle, volume) is the flyout card's.
        MediaPill {
            id: strip
            width: implicitWidth
            height: Tokyo.pillHeight
        }

        ClockFace {
            id: face
            // The face's own metrics, not the live text: sized off `contentW`,
            // so the pill never resizes on the second. See ClockFace.qml.
            width: face.contentW
            height: Tokyo.pillHeight
            // `hovered`, not `lit`: nothing borrows this pill's hover state any
            // more. The flyout is a separate surface on the far side of the
            // screen, so it never covers the pill and the bar's MouseArea keeps
            // hearing the pointer for as long as it is really there.
            hovered: root.hovered
            now: root.now
        }

        // Mirror the strip's width so the Row (and the face inside it) stays
        // centred when the strip appears; hidden with the strip, so idle has
        // zero padding to either side.
        Item {
            id: mirror
            width: strip.width
            height: 1
            visible: strip.visible
        }
    }

    onClicked: button => {
        if (button === Qt.LeftButton && root.flyoutHost) root.flyoutHost.toggleFor(root)
    }
}