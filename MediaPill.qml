// MediaPill.qml — the "now playing" fragment fused into the bar's centre pill.
//
// No chrome of its own: Clock.qml is the Module, and its Row centre-installs
// this strip so an equal-width mirror behind the clock face keeps the face
// dead centre no matter how wide the strip is (the pill grows and the clock
// does not move). Idle — no player with a title — the strip collapses to
// nothing and the pill is exactly the plain clock it always was.
//
// The bar has room for the moment's essential two: pause/play on the left,
// skip on the right, around a stationary square of the art. The spinning
// record and everything else are the flyout's NOW PLAYING card; the title
// lives there too, not here.
import QtQuick
import QtQuick.Effects

Row {
    id: root

    visible: Media.active
    height: Tokyo.pillHeight
    spacing: 6

    PillButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: Media.isPlaying ? "\uF04C" : "\uF04B"     // pause / play
        accent: Tokyo.green
        enabled: Media.canToggle
        onClicked: Media.togglePlaying()
    }

    // Stationary square. Greyscale like the flyout's record, but no spin and
    // no circular mask — the bar reads it as a thumb, not a turntable.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16

        // Drawn fallback while there is no art (idle fetch, or none offered).
        Rectangle {
            anchors.fill: parent
            visible: Media.artSource === ""
            radius: 2
            color: Tokyo.bgHighlight
            border.color: Tokyo.bgDark
            border.width: 1
        }
        Image {
            id: art
            anchors.fill: parent
            source: Media.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false          // drawn through the effect below
        }
        MultiEffect {
            anchors.fill: parent
            source: art
            saturation: 0
        }
    }

    PillButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "\uF051"                                 // forward
        accent: Tokyo.blue
        enabled: Media.canNext
        onClicked: Media.next()
    }
}