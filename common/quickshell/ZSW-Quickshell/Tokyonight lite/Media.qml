import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Now-playing pill, for music. A browser publishes MPRIS for any tab that
// makes sound, so a YouTube video would otherwise sit in the bar as if it were
// a track; browser players are skipped. The pill only exists while a player is
// actually playing — a paused track is what the player's own window is for.
Module {
    id: root

    /// Player the panel picked, by dbus name. Empty = follow whatever is
    /// playing. A picked player wins only while it is actually playing, so a
    /// paused pick cannot keep the pill hidden while something else plays.
    property string selected: ""

    readonly property var allPlayers: {
        const players = Mpris.players.values
        return players.filter(p => !root.isBrowser(p))
    }

    readonly property var player: {
        const chosen = root.allPlayers.find(p => p.dbusName === root.selected)
        if (chosen && chosen.isPlaying) return chosen
        return root.allPlayers.find(p => p.isPlaying) ?? null
    }

    /// What the picker marks as current: the chosen one, or the one the pill
    /// is showing when nothing was chosen.
    function isCurrent(p) {
        if (root.selected !== "") return p.dbusName === root.selected
        return root.player !== null && p.dbusName === root.player.dbusName
    }

    function pick(p) {
        root.selected = p.dbusName
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
}
