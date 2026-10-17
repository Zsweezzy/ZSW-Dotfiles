pragma Singleton
// Media.qml — the one "now playing" service for the whole shell.
//
// Every source is an MPRIS player. Spotify, Firefox and Chrome all publish one,
// so this is a thin, honest wrapper over Quickshell.Services.Mpris: it picks the
// player worth showing, names its source, and forwards the controls the bar pill
// and the clock flyout's NOW PLAYING card ask for. Nothing here talks to a
// player directly, and nothing polls — except the position tick below, which
// MPRIS forces.
//
// WHY A SINGLETON. The bar pill and the flyout card are two views of one song;
// two `Mpris.players` reads would be two opinions about which player is playing.
// One service, one answer.
//
// ART. MPRIS hands us `trackArtUrl`. Spotify points it at an https URL; a
// browser usually points at nothing, or at a local file. Either way the art is
// fetched once by scripts/media-art.sh into a content-addressed cache and read
// back as a file — a reload, a network blip or a re-digitized cover never
// blanks the record, and the cached file is already greyscaled, so no view has
// to run a shader for the black-and-white look. `artUrl` stays as the player
// sent it; `artSource` is what a view loads.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    // ---------- which player ----------
    // A playing player wins; else the first controllable one; else nothing.
    // Several browsers can hold a session at once, so "players[0]" alone would
    // show whichever registered first rather than what is actually on.
    readonly property var player: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;
        const playing = list.find(p => p.isPlaying && p.canControl);
        if (playing !== undefined) return playing;
        const controllable = list.find(p => p.canControl);
        return controllable !== undefined ? controllable : list[0];
    }

    /// Worth drawing anywhere: a real title, not just a parked player.
    readonly property bool active: player !== null && player.trackTitle !== ""

    // ---------- source ----------
    // MPRIS has no idea what "Spotify" or "YouTube" is; the bus identity does —
    // except for the case that matters most. A YouTube tab in Firefox or Chrome
    // announces itself as the *browser*, so on identity alone every web stream
    // would read "BROWSER". The page's own `xesam:url` is the truthful signal,
    // and it is the whole reason this is not a one-line lowercased match.
    readonly property string source: {
        const p = root.player;
        if (p === null) return "";
        const id = ((p.identity || "") + " " + (p.desktopEntry || "")).toLowerCase();
        if (id.indexOf("spotify") >= 0) return "spotify";
        const url = String((p.metadata && p.metadata["xesam:url"]) || "").toLowerCase();
        if (id.indexOf("youtube") >= 0
                || url.indexOf("youtube.com") >= 0 || url.indexOf("youtu.be") >= 0)
            return "youtube";
        if (/firefox|chrome|chromium|brave|vivaldi|opera|edge|mpv|vlc|celluloid/.test(id)) return "browser";
        return "other";
    }
    readonly property string sourceLabel:
        root.source === "spotify" ? "SPOTIFY"
        : root.source === "youtube" ? "YOUTUBE"
        : root.source === "browser" ? "BROWSER"
        : root.source === "other" ? "MEDIA"
        : ""

    // ---------- metadata ----------
    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string album: player ? player.trackAlbum : ""
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property bool isPlaying: player ? player.isPlaying : false

    readonly property bool canToggle: player ? player.canTogglePlaying : false
    readonly property bool canNext: player ? player.canGoNext : false
    readonly property bool canPrevious: player ? player.canGoPrevious : false
    readonly property bool canSeek: player ? player.canSeek : false
    readonly property bool positionSupported: player ? player.positionSupported : false
    readonly property bool volumeSupported: player ? player.volumeSupported : false
    readonly property bool loopSupported: player ? player.loopSupported : false
    readonly property bool shuffleSupported: player ? player.shuffleSupported : false

    readonly property bool shuffled: player ? player.shuffle : false
    readonly property int loopState: player ? player.loopState : MprisLoopState.None
    readonly property bool looping: loopState !== MprisLoopState.None
    readonly property bool loopTrack: loopState === MprisLoopState.Track
    readonly property real length: player ? player.length : 0
    readonly property real volume: player ? Math.max(0, Math.min(1, player.volume)) : 0

    /// Shuffle is a Spotify-only button. MPRIS exposes the read state everywhere;
    /// almost nobody implements the *setter* (Spotify does, most browsers do not),
    /// so a button that lit up but did nothing would be the bug.
    readonly property bool shuffleAvailable: root.shuffleSupported && root.source === "spotify"

    // ---------- position ----------
    // MPRIS position does not notify on its own: a player only updates it when
    // asked, to avoid a property write every second. `readonly property real
    // position: player.position` would therefore freeze at the value read when
    // the track changed. The comma expression keeps the tick as a binding
    // dependency while returning the fresh read.
    property int posTick: 0
    readonly property real position: (posTick, player ? player.position : 0)

    Timer {
        interval: 1000
        repeat: true
        running: root.isPlaying
        onTriggered: root.posTick += 1
    }

    // ---------- art ----------
    /// Cached local path for the current art, or "" while it is fetched.
    property string artPath: ""
    /// The URL the in-flight fetch was started for, so a result for a track we
    /// have already skipped past is dropped instead of drawn.
    property string fetchUrl: ""

    readonly property string artSource: root.artPath !== "" ? "file://" + root.artPath : ""

    function refreshArt(): void {
        root.artPath = "";
        const u = root.artUrl;
        root.fetchUrl = u;
        if (u === "") return;
        // The script is the scheme gatekeeper (web and local files only); the
        // argv is the URL, so nothing player-supplied reaches a shell.
        artProc.exec(["bash", Tokyo.scriptDir + "/media-art.sh", u]);
    }

    onArtUrlChanged: root.refreshArt()
    Component.onCompleted: root.refreshArt()

    Process {
        id: artProc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "" && root.fetchUrl === root.artUrl)
                    root.artPath = path;
            }
        }
    }

    // ---------- controls ----------
    function togglePlaying(): void { if (root.canToggle && root.player) root.player.togglePlaying() }
    function next(): void { if (root.canNext && root.player) root.player.next() }
    function previous(): void { if (root.canPrevious && root.player) root.player.previous() }
    function seekBy(seconds: real): void { if (root.canSeek && root.player) root.player.seek(seconds) }
    function seekTo(seconds: real): void {
        if (root.canSeek && root.positionSupported && root.player && seconds >= 0)
            root.player.position = seconds;
    }
    function setVolume(v: real): void {
        if (root.volumeSupported && root.player)
            root.player.volume = Math.max(0, Math.min(1, v));
    }
    function toggleShuffle(): void {
        if (root.shuffleAvailable && root.player) root.player.shuffle = !root.player.shuffle;
    }
    function cycleLoop(): void {
        if (!root.loopSupported || !root.player) return;
        const s = root.player.loopState;
        root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
            : s === MprisLoopState.Playlist ? MprisLoopState.Track
            : MprisLoopState.None;
    }
}
