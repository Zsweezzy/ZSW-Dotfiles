// WeatherCard.qml — the WEATHER card in the clock flyout.
//
// A full QuadCell, so ClockFlyout.qml only has to place it. Everything is a
// function of the one `Weather` singleton, which is why this card and the bar
// pill can never disagree about the temperature. No data yet is a state, not
// an absence: the card stays put and says "reading weather…", so the flyout's
// shape does not jump while the first fetch is in flight.
//
// Blocks, top-anchored and measured off their own tails (the clock card's
// pattern): the place, the temperature with its condition, three figures
// (pressure / humidity / wind, in the units `Weather` resolves for the
// place), then FLOW — the next hours' temperatures, 3h apart, coloured by
// whether they climb or fall from the reading before them.
import QtQuick

QuadCell {
    id: root

    title: "WEATHER"
    accent: Tokyo.orange

    // ---------- helpers ----------
    // Nerd Font "weather icons" glyphs, verified present in the font file.
    // `day` is the API's is_day flag; WMO weather codes to the glyph/label
    // this shell can actually draw.
    function glyphFor(code, day): string {
        switch (code) {
        case 0:    return day ? "\uE30D" : "\uE32B";       // clear
        case 1:
        case 2:    return day ? "\uE302" : "\uE32E";       // partly cloudy
        case 3:    return "\uE312";                        // overcast
        case 45:
        case 48:   return day ? "\uE303" : "\uE346";       // fog
        case 51:
        case 53:
        case 55:
        case 56:
        case 57:   return "\uE31B";                        // drizzle
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:   return day ? "\uE318" : "\uE333";       // rain
        case 71:
        case 73:
        case 75:
        case 77:   return day ? "\uE31A" : "\uE335";       // snow
        case 80:
        case 81:
        case 82:   return "\uE319";                        // showers
        case 85:
        case 86:   return day ? "\uE31A" : "\uE335";       // snow showers
        case 95:
        case 96:
        case 99:   return day ? "\uE31D" : "\uE338";       // thunderstorm
        default:   return "\uE33D";                        // cloud
        }
    }
    function labelFor(code): string {
        switch (code) {
        case 0:    return "Clear";
        case 1:
        case 2:    return "Partly cloudy";
        case 3:    return "Overcast";
        case 45:
        case 48:   return "Fog";
        case 51:
        case 53:
        case 55:
        case 56:
        case 57:   return "Drizzle";
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:   return "Rain";
        case 71:
        case 73:
        case 75:
        case 77:   return "Snow";
        case 80:
        case 81:
        case 82:   return "Showers";
        case 85:
        case 86:   return "Snow showers";
        case 95:
        case 96:
        case 99:   return "Thunderstorm";
        default:   return "";
        }
    }
    // The trend a flow slot shows: whether it climbs or falls from the slot
    // before it — the first slot from the current reading. Green up, orange
    // down, foreground when it holds.
    function trendColor(index): color {
        const prev = index === 0 ? Weather.temp : Weather.flow[index - 1].temp;
        const v = Weather.flow[index].temp;
        if (v > prev) return Tokyo.green;
        if (v < prev) return Tokyo.orange;
        return Tokyo.fg;
    }

    // ---------- body ----------
    Item {
        id: weatherBody
        anchors { left: parent.left; right: parent.right; top: parent.top }

        // ---------- block 1: the place ----------
        Text {
            id: placeLine
            anchors { left: parent.left; right: parent.right; top: parent.top }
            text: Weather.has ? Weather.name : "reading weather…"
            color: Weather.has ? Tokyo.trayGlyph : Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 11 }
            elide: Text.ElideRight
        }

        // ---------- block 2: temperature + condition ----------
        Item {
            id: nowBlock
            anchors {
                left: parent.left; right: parent.right
                top: placeLine.bottom; topMargin: 4
            }
            visible: Weather.has
            readonly property real tail: Math.max(
                feelsLine.y + feelsLine.height,
                Math.max(condLabel.y + condLabel.height, unit.y + unit.height))
            height: tail

            Text {
                id: bigTemp
                anchors { left: parent.left; top: parent.top }
                text: Math.round(Weather.temp) + "°"
                color: Tokyo.fg
                font { family: Tokyo.fontFamily; pixelSize: 28; bold: true; letterSpacing: 0.5 }
            }
            Text {
                id: unit
                anchors { left: bigTemp.right; leftMargin: 2; bottom: bigTemp.bottom; bottomMargin: 1 }
                text: Weather.tempUnit
                color: Tokyo.fg
                font { family: Tokyo.fontFamily; pixelSize: 13; bold: true }
            }
            Text {
                id: condGlyph
                anchors { right: parent.right; top: bigTemp.top; topMargin: -2 }
                text: root.glyphFor(Weather.code, Weather.isDay)
                color: Tokyo.orange
                font { family: Tokyo.fontFamily; pixelSize: 20 }
            }
            Text {
                id: condLabel
                anchors { right: parent.right; top: condGlyph.bottom; topMargin: 1 }
                width: 110
                text: root.labelFor(Weather.code)
                color: Tokyo.trayGlyph
                font { family: Tokyo.fontFamily; pixelSize: 10 }
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
            Text {
                id: feelsLine
                anchors { left: parent.left; top: bigTemp.bottom; topMargin: 3 }
                text: "feels like " + Math.round(Weather.feels) + Weather.tempUnit
                color: Tokyo.trayGlyph
                font { family: Tokyo.fontFamily; pixelSize: 10 }
            }
        }

        // ---------- block 3: pressure / humidity / wind ----------
        Item {
            id: detailBlock
            anchors {
                left: parent.left; right: parent.right
                top: nowBlock.bottom; topMargin: 8
            }
            visible: Weather.has
            readonly property real tail: 26
            height: tail

            // Three equal fixed columns, driven from the left (the zones
            // pattern) so each figure stays under its own label.
            Text {
                id: pLabel
                anchors { left: parent.left; top: parent.top }
                text: "PRESSURE"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 9; bold: true; letterSpacing: 1.5 }
            }
            Text {
                id: pValue
                anchors { left: parent.left; top: pLabel.bottom; topMargin: 2 }
                text: Weather.pressure + " " + Weather.pressureUnit
                color: Tokyo.fg
                font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
            }
            Text {
                id: hLabel
                anchors { left: parent.left; leftMargin: parent.width * 0.34; top: parent.top }
                text: "HUMIDITY"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 9; bold: true; letterSpacing: 1.5 }
            }
            Text {
                id: hValue
                anchors { left: hLabel.left; top: hLabel.bottom; topMargin: 2 }
                text: Weather.humidity + "%"
                color: Tokyo.fg
                font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
            }
            Text {
                id: wLabel
                anchors { right: parent.right; top: parent.top }
                text: "WIND"
                color: Tokyo.dim
                font { family: Tokyo.fontFamily; pixelSize: 9; bold: true; letterSpacing: 1.5 }
            }
            Text {
                id: wValue
                anchors { right: parent.right; top: wLabel.bottom; topMargin: 2 }
                text: Math.round(Weather.wind) + " " + Weather.windUnit
                color: Tokyo.fg
                font { family: Tokyo.fontFamily; pixelSize: 12; bold: true }
            }
        }

        // ---------- block 4: the weather flow ----------
        Item {
            id: flowBlock
            anchors {
                left: parent.left; right: parent.right
                top: detailBlock.bottom; topMargin: 10
            }
            visible: Weather.has && Weather.flow.length > 0
            readonly property real tail: slots.y + slots.height
            height: tail

            Text {
                id: flowLabel
                anchors { left: parent.left; top: parent.top }
                text: "FLOW"
                color: Tokyo.orange
                font { family: Tokyo.fontFamily; pixelSize: 10; bold: true; letterSpacing: 1.5 }
            }

            // Next hours, one column per slot: the time over the temperature,
            // coloured by the slope against the slot before it.
            Item {
                id: slots
                anchors { left: parent.left; right: parent.right; top: flowLabel.bottom; topMargin: 4 }
                height: 24

                Repeater {
                    model: Weather.flow
                    delegate: Item {
                        required property var modelData
                        required property int index

                        readonly property real slotW: parent.width / Math.max(1, Weather.flow.length)
                        width: slotW
                        height: parent.height
                        x: index * slotW

                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                            text: modelData.h
                            color: Tokyo.dim
                            font { family: Tokyo.fontFamily; pixelSize: 9 }
                        }
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 10 }
                            text: Math.round(modelData.temp) + "°"
                            color: root.trendColor(index)
                            font { family: Tokyo.fontFamily; pixelSize: 11; bold: true }
                        }
                    }
                }
            }
        }
    }
}