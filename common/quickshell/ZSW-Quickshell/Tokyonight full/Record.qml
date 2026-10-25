// Record.qml — album art as a spinning vinyl disc.
//
// The art MPRIS gives us is a colour JPEG; the shell wants a black-and-white
// record, so the image goes through MultiEffect: `saturation: 0` is the
// greyscale and the same effect's mask is the only way QML can clip to a circle
// (an Image has square bounds, `radius` and `clip` do not round). When there is
// no art — a browser usually sends none — a drawn disc shows instead, so the
// record's spin is a constant and only its face changes.
//
// `spinning` is the caller's: the bar pill and the flyout card both hand it
// `Media.isPlaying`, so a paused deck stands still in both at once.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    /// local file URL from Media.artSource; "" = draw the fallback disc
    property string artSource: ""
    /// the fallback's centre label — the caller's one hit of colour
    property color labelColor: Tokyo.magenta
    property bool spinning: false

    readonly property bool hasArt: root.artSource !== ""

    // The drawn vinyl, always underneath: it is what shows while the fetch is
    // still in flight and what stays if the fetch never lands.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Tokyo.bgHighlight
        border.color: Tokyo.bgDark
        border.width: 1
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.40
        height: width
        radius: width / 2
        color: root.labelColor
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.10
        height: width
        radius: width / 2
        color: Tokyo.bgDark
    }

    // The art, greyscale, masked to the disc, and rotating as one. The whole
    // Item turns rather than the effect, so the mask turns with the image.
    Item {
        id: spin
        anchors.fill: parent
        visible: root.hasArt
        rotation: 0

        Image {
            id: art
            anchors.fill: parent
            source: root.artSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false          // drawn through the effect below
        }
        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: width / 2
            color: "white"
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: art
            maskSource: artMask
            maskEnabled: true
            saturation: 0
        }

        // 8s per turn. The `from: 0` restart is the known limit here: pausing
        // mid-turn snaps the disc back to 0 when it resumes.
        // shortcut: restart-from-zero on resume, hide the seam once it annoys
        NumberAnimation on rotation {
            running: root.spinning
            from: 0; to: 360
            duration: 8000
            loops: Animation.Infinite
        }
    }
}
