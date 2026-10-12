// WeatherPill.qml — the temperature fragment fused into the bar's centre pill.
//
// No chrome of its own: Clock.qml is the Module, and its Row installs this
// right of the clock face. The pill is a Text box centred on its row; the
// face's digits sit a few px above the row's centre (they are the top line of
// a two-line block), so Clock.qml passes the face's `timeCenterOffset` as this
// pill's vertical offset — the reading lines up with the numerals, not with
// the pill's middle. Temperature only, no place name: the location, pressure
// and forecast are the flyout card's. Gray, like the reading it is: a number
// on the clock, not a brand.
import QtQuick

Text {
    id: root

    anchors.verticalCenter: parent.verticalCenter
    text: Weather.has ? Math.round(Weather.temp) + "°" : "–°"
    color: Weather.has ? Tokyo.fg : Tokyo.dim
    font { family: Tokyo.fontFamily; pixelSize: 13; bold: true }
}