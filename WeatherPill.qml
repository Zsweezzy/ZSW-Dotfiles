// WeatherPill.qml — the temperature fragment fused into the bar's centre pill.
//
// No chrome of its own: Clock.qml is the Module, and its Row centre-installs
// this to the right of the clock face while an equal-width balance mirror on
// the far left keeps the face dead centre — the pill grows to the right, the
// clock does not move. Temperature only, no place name: the location, the
// pressure, and the forecast are the flyout card's.
import QtQuick

Text {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    text: Weather.has ? Math.round(Weather.temp) + "°" : "–°"
    color: Weather.has ? Tokyo.orange : Tokyo.dim
    font { family: Tokyo.fontFamily; pixelSize: 13; bold: true }
    opacity: Weather.has ? 1 : 0.6
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }
}