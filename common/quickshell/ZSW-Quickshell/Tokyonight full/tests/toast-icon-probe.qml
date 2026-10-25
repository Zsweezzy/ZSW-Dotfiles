// toast-icon-probe.qml — run by tests/test-toast-icon-size.sh.
//
// Loads the REAL NotifyIcon.qml twice, points each at a real SVG fixture, and
// saves a grab of a solid-background box around each icon. The test trims the
// grabs to the drawn icon's bounding box, which is how the regression shows up:
// the old width/height clamp was circular and collapsed every icon to 1x1.
//
// Absolute paths only: quickshell loads a config from a virtual `qrc:` base, so
// a relative Loader source silently resolves to `qrc:/qs-blackhole` and errors.
// The repo root is read from TOAST_ICON_REPO, set by the test.
//
// Grabs go to OUT_DIR (created by the test). grabToImage callbacks are async,
// so Qt.exit(0) waits until both have fired.
import QtQuick
import Quickshell

Window {
    id: win
    width: 190
    height: 100
    color: "#101010"
    visible: true

    readonly property string outDir: "/tmp/opencode/toast-icon-probe"
    readonly property string iconComponent: {
        const repo = String(Quickshell.env("TOAST_ICON_REPO") || "")
        return repo !== "" ? "file://" + repo + "/NotifyIcon.qml" : ""
    }

    // Minimal store: every name misses the theme map, so each fixture is drawn
    // straight from its real image path and nothing else is exercised.
    QtObject {
        id: stubStore
        function iconFor(name) { return "" }
    }

    property int pending: 0

    function grab(box, name) {
        pending++
        box.grabToImage(function(result) {
            result.saveToFile(win.outDir + "/" + name + ".png")
            pending--
            if (pending === 0)
                Qt.exit(0)
        })
    }

    // The Image is asynchronous; give the SVGs time to decode before grabbing.
    Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: {
            win.grab(nordBox, "nordvpn")
            win.grab(cachyBox, "cachy")
        }
    }

    // A 40px icon centred in an 80px solid box: trim finds the icon, and the
    // margin keeps the icon off the grab edge.
    Rectangle {
        id: nordBox
        x: 10; y: 10
        width: 80; height: 80
        color: "#ff00ff"

        Loader {
            width: 40; height: 40
            anchors.centerIn: parent
            source: win.iconComponent
            onLoaded: {
                item.size = 40
                item.store = stubStore
                item.source = {
                    image: "/usr/share/icons/hicolor/scalable/apps/nordvpn.svg",
                    appIcon: "",
                    desktopEntry: "",
                }
            }
        }
    }

    Rectangle {
        id: cachyBox
        x: 100; y: 10
        width: 80; height: 80
        color: "#ff00ff"

        Loader {
            width: 40; height: 40
            anchors.centerIn: parent
            source: win.iconComponent
            onLoaded: {
                item.size = 40
                item.store = stubStore
                item.source = {
                    image: "/usr/share/icons/hicolor/scalable/apps/cachy-update_updates-available-blue.svg",
                    appIcon: "",
                    desktopEntry: "",
                }
            }
        }
    }
}
