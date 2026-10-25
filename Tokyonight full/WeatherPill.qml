// WeatherPill.qml — the temperature fragment in the bar's centre pill.
//
// No chrome of its own: Clock.qml is the Module, and its right-hand box of
// three equal-width boxes centre-installs this. The pill is plain text,
// horizontally centred on a fixed `contentW` box, so it is dead centre of its
// box whether the reading is "–°" or "24°". Temperature only, no place name:
// the location, pressure and forecast are the flyout card's. Gray, like the
// reading it is: a number on the clock, not a brand.
import QtQuick

Text {
    id: root

    /// The widest reading the pill can draw — `88°C`, measured, so Clock's box
    /// widths never depend on the current text or change when the fetch lands.
    readonly property real contentW: pillWorst.width

    width: contentW
    horizontalAlignment: Text.AlignHCenter

    text: Weather.has ? Math.round(Weather.temp) + Weather.tempUnit : "–°"
    color: Weather.has ? Tokyo.fg : Tokyo.dim
    font { family: Tokyo.fontFamily; pixelSize: 13; bold: true }

    // Follows ClockFace: a `Text` nested in an Item reports its width only
    // after layout, so the worst case is measured, not read off the live text.
    TextMetrics { id: pillWorst; font: root.font; text: "88°C" }
}