// TrayIcon.qml — one 18px tray icon with theme-name resolution + glyph fallback.
//
// QtQuick's Image can't resolve freedesktop icon-theme names, so the icon name
// (an SNI `icon` or a window class) is handed to scripts/icon-resolve.sh which
// prints a real file path; only then is it assigned to the Image. Until an icon
// resolves (or if none exists) a fallback glyph is shown instead — a per-app
// nerd-font glyph when fallbackGlyph is set (e.g. "\uf1b6" for Steam), else the
// generic window glyph.
//
// The `sleep 0.1` keeps the one-shot process alive so the final bytes of the
// resolved path drain out of the pipe before exit (same quirk documented in
// Poll.qml).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    /// icon theme name, existing file path, or "" to force the glyph
    property string iconArg: ""
    /// nerd-font glyph shown while no icon resolves (e.g. "\uf1b6" for Steam);
    /// "" falls back to the generic window glyph
    property string fallbackGlyph: ""
    property bool showGlyph: true

    width: 18
    height: 18

    // fallback glyph — visible only while no real icon is loaded; per-app
    // override via root.fallbackGlyph, otherwise the generic window glyph
    Text {
        anchors.centerIn: parent
        text: root.fallbackGlyph !== "" ? root.fallbackGlyph : "\uf2d2" // nf-fa-window_restore
        color: Tokyo.fg
        font { family: Tokyo.fontFamily; pixelSize: 12 }
        visible: root.showGlyph && !iconView.valid
    }

    IconImage {
        id: iconView
        anchors.fill: parent
        implicitSize: 18
        readonly property bool valid: source !== "" && status !== Image.Error
    }

    Process {
        id: resolve

        stdout: SplitParser {
            onRead: msg => {
                const out = String(msg).trim()
                if (out !== "") iconView.source = "file://" + out.replace(/ /g, "%20")
            }
        }
    }

    function shellQuote(s) {
        return "'" + String(s || "").replace(/'/g, "'\\''") + "'"
    }

    function wrappedCommand() {
        return "(" + Tokyo.scriptDir + "/icon-resolve.sh " + root.shellQuote(root.iconArg) + " 18; printf '\\n'); sleep 0.1"
    }

    onIconArgChanged: {
        resolve.command = ["sh", "-c", root.wrappedCommand()]
        resolve.running = root.iconArg !== ""
    }

    Component.onCompleted: {
        if (root.iconArg !== "") {
            resolve.command = ["sh", "-c", root.wrappedCommand()]
            resolve.running = true
        }
    }
}