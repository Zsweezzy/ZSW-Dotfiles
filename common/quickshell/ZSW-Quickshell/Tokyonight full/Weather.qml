pragma Singleton
// Weather.qml — the one weather service for the whole shell.
//
// Two views read it (the temperature in the bar's centre pill, the full card
// in the clock flyout), so one service, one answer — exactly the Media
// arrangement.
//
// THE CONFIG IS THESE TWO LINES. Change the place (or give a "lat,lon" pair
// for an exact spot) and the unit convention, save, and the file watcher
// reloads the bar; the next fetch uses the new values. `auto` answers with the
// convention of the resolved country — °C / km/h / hPa, or °F / mph / inHg for
// US, Liberia and Myanmar. `metric` and `imperial` force a side.
//
// REFRESH. A 10-minute timer owns the cadence; a failed fetch (the script
// prints nothing) keeps the last good reading. The geocoder result is cached
// for a day by scripts/weather.sh, so every reload is a forecast fetch, not a
// re-geocode — cheap, and kind to the free API. Quickshell's JS engine has no
// Intl or TimeZone, so the script pre-formats each flow slot's local HH:mm in
// the location's own zone; this side only formats numbers.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---------- the config ----------
    property string weatherLocation: "Breckerfeld, Germany"
    property string weatherUnits: "auto"

    // ---------- current reading ----------
    property bool has: false
    property string name: ""
    property real temp: 0
    property real feels: 0
    property int humidity: 0
    property int pressure: 0
    property string pressureUnit: "hPa"
    property real wind: 0
    property string windUnit: "km/h"
    property string tempUnit: "°C"
    property int code: 0
    property bool isDay: true
    /// [{ h, temp, code, isDay }] — the next hours, 3h apart, location-local HH:mm
    property var flow: []

    // ---------- fetch ----------
    /// Config pair the in-flight fetch was started for, so a result for a
    /// location we have already switched away from is dropped, not drawn.
    property string runKey: ""
    property bool fetching: false

    function refresh(): void {
        if (root.fetching) return;
        root.fetching = true;
        root.runKey = root.weatherLocation + "|" + root.weatherUnits;
        weatherProc.exec(["bash", Tokyo.scriptDir + "/weather.sh",
                          root.weatherLocation, root.weatherUnits]);
    }

    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    onWeatherLocationChanged: root.refresh()
    onWeatherUnitsChanged: root.refresh()
    Component.onCompleted: root.refresh()

    Process {
        id: weatherProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.fetching = false;
                if (root.runKey !== root.weatherLocation + "|" + root.weatherUnits)
                    return;                                  // stale — switched away
                const t = text.trim();
                if (t === "") return;                        // script failed; keep last good
                let o;
                try { o = JSON.parse(t); } catch (err) { return; }
                root.name = String(o.name || "");
                root.temp = Number(o.temp) || 0;
                root.feels = Number(o.feels) || 0;
                root.humidity = Number(o.humidity) || 0;
                root.pressure = Number(o.pressure) || 0;
                root.pressureUnit = String(o.pressureUnit || "hPa");
                root.wind = Number(o.wind) || 0;
                root.windUnit = String(o.windUnit || "km/h");
                root.tempUnit = String(o.tempUnit || "°C");
                root.code = Number(o.code) || 0;
                root.isDay = Number(o.isDay) !== 0;
                root.flow = Array.isArray(o.flow) ? o.flow.slice(0, 12) : [];
                root.has = true;
            }
        }
    }
}