import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Now-playing pill, for music. A browser publishes MPRIS for any tab that
// makes sound, so a YouTube video would otherwise sit in the bar as if it were
// a track; browser players are skipped. The pill only exists while a player is
// actually playing — a paused track is what the player's own window is for.
Module {
    id: root

    readonly property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying && !root.isBrowser(p)) ?? null
    }
    readonly property string title: root.player ? (root.player.trackTitle ?? "") : ""
    readonly property bool playing: root.player ? root.player.isPlaying : false

    // The capsule is sized by its pills, so a 40-character title would widen
    // the bar across the screen. The panel is where the full one is read.
    readonly property string label: root.title.length > 22
                                       ? root.title.slice(0, 21) + "…"
                                       : root.title

    function isBrowser(p) {
        const id = String(p.dbusName ?? "") + " " + String(p.identity ?? "")
                   + " " + String(p.desktopEntry ?? "")
        return /chromium|chrome|helium|firefox|brave|vivaldi|opera|edge/i.test(id)
    }

    visible: root.player !== null && root.title !== ""
    fg: Tokyo.magenta
    text: "\uf04b " + root.label
    tooltip: root.player ? root.player.identity + " — " + root.title : ""

    panel: Component {
        MediaPanel { mediaModule: root }
    }
}
