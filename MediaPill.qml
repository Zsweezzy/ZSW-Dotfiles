// MediaPill.qml — the "now playing" fragment in the bar's centre pill.
//
// No chrome of its own: Clock.qml is the Module, and it centre-installs this
// strip inside the left of three equal-width boxes, so the pill keeps one
// width whether the strip is there or not. Idle — no player with a title —
// the strip collapses to nothing and its box stays empty behind it.
//
// The bar has room for the moment's essential two: pause/play on the left,
// skip on the right, around a stationary square of the art. The controls are
// bare white glyphs — in a 26px pill a bordered square per button is noise,
// and the art square is the only shape that should compete with the clock
// face. Disabled is a fade and nothing else. The glyphs are plain Text with a
// widened MouseArea hitbox, duplicated twice rather than factored into a
// component: this file's root is a positioner, and that is the one place this
// Qt build does not hoist inline components.
import QtQuick

Row {
    id: root

    visible: Media.active
    height: Tokyo.pillHeight
    spacing: 6

    // pause / play — white glyph, no pill, no accent. The MouseArea bleeds
    // 7px past the glyph so the touch target stays a button, not a stroke.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Media.isPlaying ? "\uF04C" : "\uF04B"
        color: Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 13; bold: true }
        opacity: Media.canToggle ? 1 : 0.4
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -7
            enabled: Media.canToggle
            onClicked: Media.togglePlaying()
        }
    }

    // Stationary square. The cached file is already greyscale (media-art.sh
    // bakes it), so a plain Image is all the black-and-white needs — no shader
    // to lie about it.
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
            anchors.fill: parent
            visible: Media.artSource !== ""
            source: Media.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    // forward
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uF051"
        color: Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 13; bold: true }
        opacity: Media.canNext ? 1 : 0.4
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -7
            enabled: Media.canNext
            onClicked: Media.next()
        }
    }
}