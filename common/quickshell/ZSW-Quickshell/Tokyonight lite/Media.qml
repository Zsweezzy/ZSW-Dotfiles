import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Now-playing pill. One player, not a list: whatever is playing wins, else the
// first one that still exists — pausing Spotify must not make the pill vanish.
Module {
    id: root

    readonly property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) ?? players[0] ?? null
    }
    readonly property string title: root.player ? (root.player.trackTitle ?? "") : ""
    readonly property bool playing: root.player ? root.player.isPlaying : false

    // The capsule is sized by its pills, so a 40-character title would widen
    // the bar across the screen. The panel is where the full one is read.
    readonly property string label: root.title.length > 22
                                       ? root.title.slice(0, 21) + "…"
                                       : root.title

    visible: root.player !== null && root.title !== ""
    fg: Tokyo.magenta
    text: root.title === "" ? "\uf001" : (root.playing ? "\uf04b " : "\uf04c ") + root.label
    tooltip: root.player ? root.player.identity + " — " + root.title : ""

    panel: Component {
        MediaPanel { mediaModule: root }
    }
}
