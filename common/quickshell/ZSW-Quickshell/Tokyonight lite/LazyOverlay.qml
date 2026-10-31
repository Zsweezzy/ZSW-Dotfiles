import QtQuick

// A Loader that only creates its overlay while `wanted`, and keeps it around
// for `graceMs` afterwards so a closing card can finish rolling up.
//
// The four overlay windows (launcher, clipboard, screenshot, polkit) cost
// roughly 20-25 MB per monitor each while mapped, which was the bulk of the
// shell's idle memory on this three-monitor desk. Only the focused monitor's
// copy is created now (region screenshots map every screen while a shot is
// running); nothing else exists until it is opened.
Loader {
    id: root

    /// Whether this overlay needs to exist right now.
    property bool wanted: false
    /// How long the close animation needs before the item can go away.
    property int graceMs: 0
    property bool live: root.wanted

    active: root.live

    onWantedChanged: {
        if (root.wanted) {
            root.live = true;
            unload.stop();
            return;
        }
        if (root.graceMs <= 0) root.live = false;
        else unload.restart();
    }

    Timer {
        id: unload
        interval: root.graceMs
        onTriggered: if (!root.wanted) root.live = false
    }
}
