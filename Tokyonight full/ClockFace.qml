// ClockFace.qml — the clock pill's contents, with no chrome: `HH:mm:ss`,
// at rest, on hover and while the popup is open. One look, and it does not
// move.
//
// It is a separate file because the pill's contents are one measurement and the
// pill's width is cut from it (see `contentW`): the font, the metrics and the
// padding arithmetic live here, exactly once. It has no clock of its own — the
// bar's `Clock` supplies the tick, the same value the popup's CLOCK card reads,
// and the hover.
import QtQuick

Item {
    id: root

    /// Set by the host from whatever MouseArea is over the face.
    property bool hovered: false

    /// The clock this face reads. Supplied, never owned: the host's timer is the
    /// only tick, so a face built against any other Date disagrees about the
    /// seconds digit.
    property var now

    /// The widest thing the face can draw, and the number the pill's width is cut
    /// from. Measured rather than read off the live text, and the reason is
    /// worth keeping: Qt rounds each character's advance separately, and it does
    /// not think this font's digits are all the same width. Measured over every
    /// time there is, `HH:mm:ss` ranges 62..64px on the seconds alone (`00:00:00`
    /// is 63, `00:00:01` is 64). A face sized off its own live text is therefore
    /// a pill that resizes once a second, which re-runs the bar's layout and
    /// slides the clock sideways. One pixel of disagreement between the pill's
    /// width and its text is what reads as a doubled clock.
    ///
    /// `timeWorst` is the widest the time can get, so the width is a constant.
    /// Re-measure it if the time's format or the font ever changes.
    readonly property real contentW: timeWorst.width

    // The time, vertically and horizontally centred in the pill. The height is
    // declared rather than left to the font's line box, so the numerals sit in
    // the middle of the pill and not at its top.
    Text {
        id: time
        anchors.centerIn: parent
        width: parent.width
        height: 15
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: Qt.formatDateTime(root.now, "HH:mm:ss")
        // Cyan on hover, like every other label in the bar, and on the same
        // 120ms the popup's own hover runs at.
        color: root.hovered ? Tokyo.cyan : Tokyo.fg
        font {
            family: Tokyo.fontFamily
            pixelSize: 13
            bold: true
            letterSpacing: 0.2
        }
        Behavior on color {
            ColorAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
    }

    // Measured rather than implicit, and read by the pill's own width: a `Text`
    // nested in an Item reports its width only after layout, and a binding that
    // reads it during the first polish is how pills end up a character short.
    TextMetrics { id: timeWorst; font: time.font; text: "08:88:88" }
}