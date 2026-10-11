// MediaPill.qml — the "now playing" pill on the left of the clock.
//
// It exists only while something is playing (`Media.active`): an idle deck
// leaves no pill at all, the same way an idle player leaves no now-playing
// line anywhere else. Clicking it opens the clock flyout — the same flyout the
// clock pill opens, which now carries the NOW PLAYING card — so it is a second
// door onto one panel rather than a panel of its own. It hands the flyout the
// *clock* pill, not itself: the flyout reads `pill.now` for its seconds, and
// this widget has no clock.
//
// The disc is `Record.qml`, the same component the flyout card draws big, so
// the small and the large record cannot drift apart.
import QtQuick

Module {
    id: root

    /// shared ClockFlyout (Bar.qml) — may be null in previews
    property var flyoutHost: null
    /// the bar's Clock, so the flyout's clock keeps its single source
    property var clockPill: null

    fg: Tokyo.fg
    hoverStyle: true
    text: ""
    visible: Media.active

    implicitHeight: Tokyo.pillHeight
    implicitWidth: content.implicitWidth + hPad * 2

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Record {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            artSource: Media.artSource
            spinning: Media.isPlaying
        }

        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            // Fixed ceiling so one long video title cannot take the bar.
            width: Math.min(implicitWidth, 150)
            text: Media.title
            elide: Text.ElideRight
            color: (root.interactive && root.hoverStyle && root.lit) ? root.hoverFg : root.fg
            font { family: Tokyo.fontFamily; pixelSize: Tokyo.fontSize; letterSpacing: root.letterSpacing }
            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }
    }

    onClicked: button => {
        if (button === Qt.LeftButton && root.flyoutHost)
            root.flyoutHost.toggleFor(root.clockPill)
    }
}
