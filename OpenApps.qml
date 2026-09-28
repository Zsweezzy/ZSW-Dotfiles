// OpenApps.qml — the apps cluster: open apps + tray background apps, one pill.
//
//   open-app glyphs  [gap]  tray background-app glyphs
//
// Foreground open apps render as pink nerd-font glyphs polled from
// scripts/openapps.sh — one clickable cell per app (left-click focuses that
// app, taskbar-style). A gap separates them from tray background apps —
// StatusNotifierItems (Steam, NordVPN, ...) and windows hidden with
// SUPER+SHIFT+C onto Hyprland's hidden special:tray workspace — which render
// in a muted blue-gray (Tokyo.trayGlyph, glyphFor() mirrors the openapps.sh
// glyph map) so opened and trayed apps read as two color-coded groups inside
// one uniform widget.
//
// A cell shows whichever it has, in this order: a mapped nerd-font glyph, else
// the app's own icon from the active icon theme (iconUrl()), else the generic
// wrench. Most apps here have no glyph worth hand-mapping, and a hand-picked
// glyph is only ever a guess at a logo — the theme's icon is the better one when
// it has one. The tradeoff is that native icons are artwork, so an icon cell is
// full-colour and only glyph cells take the pink/muted tint that colour-codes
// the two groups.
//
// Every cell is its own click target (≥24 px, ~12 px gaps between glyphs, and
// glyphs are a px bigger than the other pills' labels so they're easy to hit):
//   Open apps:  left-click focuses that app's window.
//   Tray cells: left-click restores the window this icon covers (if one is
//               hidden in the tray) or activates the app; right-click opens the
//               app's own SNI menu when it has one.
//
// The pill collapses to nothing when there is no content (no open apps, no
// SNI items, no tray'd windows) and reappears when any of them return.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray

Rectangle {
    id: root

    /// shared tooltip popup (passed from Bar.qml)
    property var tooltipHost: null

    implicitHeight: Tokyo.pillHeight
    // the contents are anchor-filled, so they don't feed the parent's implicit
    // size themselves — implicitWidth is driven by the inner row instead.
    implicitWidth: contentRow.implicitWidth + Tokyo.pillHPad * 2
    radius: Tokyo.pillRadius
    color: Tokyo.pillBg
    visible: root.hasOpenApps || root.hasTrayContent

    // ---------- content state ----------
    property var parsed: ({ apps: [] }) // open-apps script output (placeholder until first run)
    readonly property bool hasOpenApps: (root.parsed && root.parsed.apps) ? root.parsed.apps.length > 0 : false
    // NOTE: quickshell 0.3.1's ObjectModel does NOT expose .count — only
    // .values, so gate on values.length (SystemTray.items.count is undefined).
    readonly property bool hasTrayContent: SystemTray.items.values.length > 0 || root.trayWindows.length > 0

    // ---------- taskbar sizing (apps cluster only — the other pills keep Tokyo.fontSize) ----------
    // "a tiny bit bigger" than the other pills' labels.
    readonly property real iconSize: Tokyo.fontSize + 1
    // last-resort glyph: only painted when the app has neither a mapped
    // nerd-font glyph nor an icon in the current theme.
    readonly property string genericGlyph: "\uf0c8"
    // cell width = the wider of glyph and icon + 12 px spacing (6 px pad each
    // side → ~12 px visual gap between cells), min 24 px so each icon is a
    // comfortable click target. The icon is in the formula so a cell is already
    // its final width when the icon is still loading — resizing then would
    // shuffle the whole row.
    readonly property real appCellPad: 12
    readonly property real appCellMin: 24

    // windows currently hidden in special:tray, minus any already covered by an SNI item
    property var trayWindows: []
    property var _rawClients: []
    on_RawClientsChanged: root.rebuild()

    // ---------- open-apps source ----------
    // Waybar polls every 5s and also refreshes on RTMIN+8; here the signal
    // refresh equivalent is a re-run of the script when windows open/close.
    Poll {
        id: openAppsPoll
        command: [Tokyo.scriptDir + "/openapps.sh"]
        interval: 5000
        onResult: output => root.parsed = root.parseJson(output)
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            const ev = ["openwindow", "closewindow", "openwindowv2", "closewindowv2"]
            if (ev.includes(e.name)) openAppsPoll.refresh()
        }
    }

    // ---------- hidden-window discovery (tray) ----------
    Poll {
        // "clients -j" alone prints PRETTY-PRINTED json (1 line per field), and
        // Poll's SplitParser fires onRead per line -> JSON.parse would fail on
        // every fragment. Compact it with jq -c so each poll run is one line.
        command: ["sh", "-c", "hyprctl clients -j | jq -c ."]
        interval: 1000
        onResult: output => {
            try {
                const arr = JSON.parse(output)
                const inTray = arr
                    .filter(c => {
                        const ws = c.workspace
                        return ws !== null && ws !== undefined && String(ws.name) === "special:tray"
                    })
                    .map(c => ({
                        address: c.address,
                        class: c.class,
                        title: c.title,
                        pid: c.pid,
                    }))
                root._rawClients = inTray
            } catch (e) {
                // transient parse failure — keep the previous list
            }
        }
    }

    function parseJson(out) {
        try {
            const o = JSON.parse(out)
            const apps = Array.isArray(o.apps) ? o.apps : []
            // keep the SAME array identity when nothing visible changed: the
            // 5 s poll re-runs this every time, and a fresh array every run
            // rebuilds the open cells — which resets the hover highlight mid-
            // hover ("hover fades out while I'm still on the icon"). Titles may
            // drift; the tooltips pick them up on the next real change.
            const cur = root.parsed && root.parsed.apps
            if (cur && cur.length === apps.length) {
                let same = true
                for (let i = 0; i < apps.length; i++) {
                    const a = cur[i]
                    const b = apps[i]
                    if (!a || !b || a.class !== b.class || a.glyph !== b.glyph) {
                        same = false
                        break
                    }
                }
                if (same) return root.parsed
            }
            return { apps }
        } catch (e) {
            return root.parsed && root.parsed.apps ? root.parsed : { apps: [] }
        }
    }

    function rebuild() {
        const wins = []
        const sni = SystemTray.items.values
        for (const c of root._rawClients) {
            if (!c.address) continue
            if (root._sniCovers(sni, c)) continue
            wins.push(c)
        }
        root.trayWindows = wins
    }

    // does any SNI item represent this window's app? (no pid on TrayItem in
    // quickshell, so we match lowercased title/id against the window class)
    function _sniCovers(items, client) {
        const cls = String(client.class || "").toLowerCase()
        if (!cls) return false
        for (const it of items) {
            const t = String(it.title || it.id || "").toLowerCase()
            if (!t) continue
            if (t === cls || t.startsWith(cls) || t.endsWith(cls)) return true
        }
        return false
    }

    // the tray'd window (if any) that this SNI item represents. When found, a
    // left click on the tray cell restores that window onto the active
    // workspace; otherwise we'd only surface the special-workspace overlay
    // (Hyprland keeps the window in special:tray, which is confusing).
    function _coveredTrayWindow(item) {
        for (const c of root._rawClients) {
            if (root._sniCovers([item], c)) return c
        }
        return null
    }

    // nerd-font glyph for an open/tray app. Mirrors the glyph map in
    // scripts/openapps.sh (keep the two in sync) plus app-specific brands for
    // the tray; "" means no font glyph is mapped, and the cell then falls back
    // to the app's own theme icon (root.iconUrl) — the generic wrench is only
    // painted by the cell when that lookup misses too. openRGB is deliberately
    // absent: the sliders glyph (\uf1de, was \uf1fb) was a stand-in for its
    // logo, and its own icon is the better one where the theme has it.
    function glyphFor(name) {
        const n = String(name || "").toLowerCase()
        if (n.indexOf("steam") !== -1) return "\uf1b6"    // nf-fa-steam
        if (n.indexOf("nordvpn") !== -1) return "\uf023"  // nf-fa-lock (was \uf132 shield — read as a generic blob at 14 px)
        if (/firefox|chromium|brave|zen|webkit/.test(n)) return "\uf269"   // browser
        if (/kitty|alacritty|wezterm|foot|konsole|ghostty|urxvt|xterm/.test(n)) return "\uf120"  // terminal
        if (/kate|kwrite|sublime|code|vim|nvim|emacs|zed/.test(n)) return "\uf044"  // editor
        if (/dolphin|nautilus|thunar|pcmanfm|nemo/.test(n)) return "\uf07b"  // file manager
        return ""
    }

    // whatever URL the Image can load for an app, or "" when nothing resolves.
    // Window classes are often reverse-DNS (org.kde.kate -> kate), so a name
    // that misses the theme is retried on its last dotted segment; an absolute
    // path is taken as one. A path that no longer exists on disk still goes to
    // the Image, which fails it and hands the cell back to its glyph — there is
    // no existence check here to fall back from (QML has no equivalent of the
    // old resolver's `[ -f "$name" ]`).
    function iconUrl(name) {
        const n = String(name || "").trim()
        if (n === "") return ""
        // an SNI icon is not always a bare theme name: Steam hands over a
        // complete provider URL (image://icon/steam_tray_mono?path=...), others
        // a generated one (image://qspixmap/...). Those are already URLs, and
        // iconPath() cannot resolve them — hand them to the Image as they are.
        if (n.indexOf("://") !== -1) return n
        let p = Quickshell.iconPath(n, true)
        if (p === "" && n.indexOf(".") !== -1) p = Quickshell.iconPath(n.split(".").pop(), true)
        if (p !== "") return p
        // nothing in the theme: an absolute path the app gave us
        if (n.indexOf("/") === 0) return "file://" + n.replace(/ /g, "%20")
        return ""
    }

    // taskbar-style click: focus that app's first window.
    // "hl.dsp.focus" is the Lua-DSL dispatcher form hyprctl dispatch expects
    // (bare "focuswindow class:..." is a syntax error, verified on 0.56.2).
    function focusApp(cls) {
        const c = String(cls || "")
        if (!c) return
        Quickshell.execDetached(["bash", "-c",
            "hyprctl dispatch \"hl.dsp.focus({ window = \\\"class:$1\\\" })\"",
            "app-focus", c])
    }

    // display a tray item's own SNI menu (Steam's Exit/Library, ...) as a
    // themed flyout (TrayMenu.qml) anchored below its cell — same flyout
    // language as the audio flyout, same position the platform menu had.
    // The menu is populated from item.menu (a QsMenuHandle) by QsMenuOpener;
    // grabFocus dismisses it on any outside click.
    function showTrayMenu(item, cell) {
        if (!item || !item.menu) return
        root.cancelTooltip()
        trayMenu.menuHandle = item.menu
        trayMenu.showFor(cell, "below")
    }

    // ---------- delayed tooltip ----------
    // Don't pop the tooltip the instant the cursor enters a cell: popping it
    // immediately while scanning across the cluster disturbed hover handling
    // and made the highlight look like it "fades out". Now the tooltip appears
    // only after the cursor rests on a cell for ~0.5 s. One shared timer means
    // only the last-scheduled cell wins. The highlight itself is position-
    // tracked (containsMouse), so resting on a cell keeps it lit regardless.
    Timer {
        id: tooltipTimer
        interval: 500
        repeat: false
        property var pendingCell: null
        property string pendingText: ""
        onTriggered: {
            if (root.tooltipHost !== null && tooltipTimer.pendingCell !== null)
                root.tooltipHost.showFor(tooltipTimer.pendingCell, tooltipTimer.pendingText)
        }
    }

    function scheduleTooltip(cell, tip) {
        tooltipTimer.pendingCell = cell
        tooltipTimer.pendingText = tip
        tooltipTimer.restart()
    }

    function cancelTooltip() {
        tooltipTimer.stop()
        if (root.tooltipHost !== null) root.tooltipHost.hide()
    }

    // move a tray'd window back onto the currently active workspace and focus it.
    // Uses the Lua DSL form of the dispatcher: hyprctl dispatch evaluates its
    // argument as Lua, so bare "movetoworkspacesilent 1,address:0x..." is a
    // syntax error. workspace + window selection need { workspace=..., window=... }.
    function restoreWindow(c) {
        const addr = String(c.address || "")
        if (!addr) return
        Quickshell.execDetached(["bash", "-c",
            "a=$1; ws=$(hyprctl activeworkspace -j | jq -r .name); hyprctl dispatch \"hl.dsp.window.move({workspace=\\\"$ws\\\", window=\\\"address:$a\\\", follow=true})\"",
            "tray-restore", addr])
    }

    // ---------- the pill ----------
    Row {
        id: contentRow
        anchors { fill: parent; leftMargin: Tokyo.pillHPad; rightMargin: Tokyo.pillHPad }
        spacing: 0

        // ---------- open apps: one clickable cell per app ----------
        Row {
            id: openRow
            // an empty model collapses the row to zero width, so no extra
            // gating is needed — the pill's own visibility covers the empty case.
            Repeater {
                model: root.parsed.apps

                delegate: Rectangle {
                    required property var modelData
                    readonly property var app: modelData

                    id: openCell
                    // same sizing as the tray cells (root.appCellPad/Min): the
                    // wider of glyph/icon + 12 px spacing, min 24 px — easy to
                    // click specific apps. Sizing on the icon too means the cell
                    // is already its final width when the icon is still loading.
                    width: Math.max(Math.max(root.iconSize, glyph.implicitWidth) + root.appCellPad, root.appCellMin)
                    height: Tokyo.pillHeight
                    radius: 6
                    // highlight tracks the cursor position itself (containsMouse)
                    // instead of enter/exit flags — an exit event can't be missed,
                    // so the highlight stays on exactly as long as the mouse is
                    // over the icon.
                    // no fade: an instant highlight means two adjacent cells can
                    // never both look "lit" during a transition (a 150 ms fade
                    // left the previous cell fading out while the next faded in,
                    // and jiggling between the tray icons made both look focused)
                    color: mouse.containsMouse ? Tokyo.cellHover : "transparent"

                    // the app's own artwork, for classes openapps.sh left unmapped
                    // (app.glyph === "") — they fall through to whatever the theme
                    // resolves for their class, and to the wrench if that misses too.
                    Image {
                        id: icon
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        fillMode: Image.PreserveAspectFit
                        // without these the image:// provider hands back a
                        // 200x200 pixmap and Qt scales it down (blurry SVG at
                        // 14 px); with them the SVG rasterizes at 14.
                        sourceSize.width: root.iconSize
                        sourceSize.height: root.iconSize
                        source: openCell.app && openCell.app.glyph === "" ? root.iconUrl(openCell.app.class) : ""
                    }

                    Text {
                        id: glyph
                        anchors.centerIn: parent
                        // "" from the map means "no glyph of ours" -> the cell
                        // falls back to the app's own icon, and only reaches the
                        // generic wrench when the theme has no icon either.
                        text: (openCell.app && openCell.app.glyph) ? openCell.app.glyph : root.genericGlyph
                        color: Tokyo.pink
                        font { family: Tokyo.fontFamily; pixelSize: root.iconSize; letterSpacing: 0.2 }
                        // the glyph stands in for a cell with no icon to paint,
                        // and a cell has none two ways: the source was empty
                        // (status Null) or the provider could not decode it
                        // (status Error — a stale path, a broken SVG). Judged on
                        // the status enum, not on `source === ""`: source is
                        // url-typed, so that comparison is never true and every
                        // blank cell lost its glyph. Loading stays hidden so the
                        // two are never painted at once.
                        visible: icon.status === Image.Null || icon.status === Image.Error
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onEntered: {
                            if (root.tooltipHost !== null && openCell.app) {
                                const tip = openCell.app.title !== "" ? openCell.app.title : openCell.app.class
                                if (tip !== "") root.scheduleTooltip(openCell, tip)
                            }
                        }
                        onExited: root.cancelTooltip()
                        onClicked: root.focusApp(openCell.app.class)
                    }
                }
            }
        }

        // ---------- inner gap: open apps vs trayed background apps ----------
        Item {
            width: (root.hasOpenApps && root.hasTrayContent) ? 8 : 0
            height: Tokyo.pillHeight
        }

        // ---------- tray background apps ----------
        Row {
            id: trayRow
            spacing: 0

            // SNI items (background apps with a StatusNotifierItem)
            Repeater {
                model: SystemTray.items

                delegate: Rectangle {
                    required property var modelData
                    readonly property var item: modelData

                    id: sniCell
                    // same sizing as open-app cells (root.appCellPad/Min): the
                    // wider of glyph/icon + 12 px spacing, min 24 px.
                    width: Math.max(Math.max(root.iconSize, glyph.implicitWidth) + root.appCellPad, root.appCellMin)
                    height: Tokyo.pillHeight
                    radius: 6
                    // no fade: an instant highlight means two adjacent cells can
                    // never both look "lit" during a transition (a 150 ms fade
                    // left the previous cell fading out while the next faded in,
                    // and jiggling between the tray icons made both look focused)
                    color: mouse.containsMouse ? Tokyo.cellHover : "transparent"

                    // the app's own icon, used whenever glyphFor() has no
                    // nerd-font glyph for it. item.icon is what the SNI hands
                    // us (a theme name, a path, or a whole image:// URL), so try
                    // it first and fall back to the SNI id.
                    // openRGB is the case this exists for: it runs
                    // --startminimized and lives here as an SNI cell, and the
                    // sliders glyph it used to be given is only a guess at its
                    // logo — so it takes whatever the theme resolves for its
                    // icon/id, and the generic wrench if that misses too.
                    Image {
                        id: icon
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        fillMode: Image.PreserveAspectFit
                        // rasterize at the target size — see the open-app cell
                        sourceSize.width: root.iconSize
                        sourceSize.height: root.iconSize
                        source: sniCell.item ? (root.iconUrl(sniCell.item.icon) || root.iconUrl(sniCell.item.id)) : ""
                    }

                    Text {
                        id: glyph
                        anchors.centerIn: parent
                        // item can be momentarily undefined while the Repeater
                        // rebuilds on reload — guard so it doesn't warn.
                        text: sniCell.item ? (root.glyphFor(sniCell.item.title + " " + sniCell.item.id + " " + sniCell.item.icon) || root.genericGlyph) : ""
                        // tray/background apps use a muted blue-gray so opened
                        // apps (pink) and trayed apps read as separate groups.
                        color: Tokyo.trayGlyph
                        font { family: Tokyo.fontFamily; pixelSize: root.iconSize; letterSpacing: 0.2 }
                        // Null/Error, i.e. no icon to show — see the open-app cell
                        visible: icon.status === Image.Null || icon.status === Image.Error
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: {
                            if (root.tooltipHost !== null) {
                                const tip = sniCell.item.tooltipTitle !== "" ? sniCell.item.tooltipTitle : sniCell.item.title
                                if (tip !== "") root.scheduleTooltip(sniCell, tip)
                            }
                        }
                        onExited: root.cancelTooltip()
                        onClicked: m => {
                            // right-click: the app's own menu (Library/Exit/etc.)
                            if (m.button === Qt.RightButton && sniCell.item.hasMenu) {
                                root.showTrayMenu(sniCell.item, sniCell)
                                return
                            }
                            // left-click: if this icon covers a window hidden in
                            // the tray, restore that window; otherwise activate.
                            const covered = root._coveredTrayWindow(sniCell.item)
                            if (covered !== null) root.restoreWindow(covered)
                            else sniCell.item.activate()
                        }
                    }
                }
            }

            // placeholders: tray'd windows that have no SNI item
            Repeater {
                model: root.trayWindows

                delegate: Rectangle {
                    required property var modelData
                    readonly property var client: modelData

                    id: phCell
                    // same sizing as SNI/open-app cells (see root.appCellPad/Min)
                    width: Math.max(Math.max(root.iconSize, glyph.implicitWidth) + root.appCellPad, root.appCellMin)
                    height: Tokyo.pillHeight
                    radius: 6
                    // no fade: an instant highlight means two adjacent cells can
                    // never both look "lit" during a transition (a 150 ms fade
                    // left the previous cell fading out while the next faded in,
                    // and jiggling between the tray icons made both look focused)
                    color: mouse.containsMouse ? Tokyo.cellHover : "transparent"

                    // same fallback as the SNI cells, from the window class
                    Image {
                        id: icon
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        fillMode: Image.PreserveAspectFit
                        // rasterize at the target size — see the open-app cell
                        sourceSize.width: root.iconSize
                        sourceSize.height: root.iconSize
                        source: phCell.client ? root.iconUrl(phCell.client.class) : ""
                    }

                    Text {
                        id: glyph
                        anchors.centerIn: parent
                        // client can be momentarily undefined while the Repeater
                        // rebuilds on reload — guard so it doesn't warn.
                        text: phCell.client ? (root.glyphFor(phCell.client.class + " " + phCell.client.title) || root.genericGlyph) : ""
                        // tray/background apps use the muted blue-gray (see SNI cell)
                        color: Tokyo.trayGlyph
                        font { family: Tokyo.fontFamily; pixelSize: root.iconSize; letterSpacing: 0.2 }
                        // Null/Error, i.e. no icon to show — see the open-app cell
                        visible: icon.status === Image.Null || icon.status === Image.Error
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            if (root.tooltipHost !== null) {
                                const tip = phCell.client.title !== "" ? phCell.client.title : phCell.client.class
                                if (tip !== "") root.scheduleTooltip(phCell, tip)
                            }
                        }
                        onExited: root.cancelTooltip()
                        onClicked: root.restoreWindow(phCell.client)
                    }
                }
            }
        }
    }

    // SNI right-click menus: a themed flyout (TrayMenu.qml) in the audio
    // flyout's visual language, populated from the tray item's QsMenuHandle by
    // QsMenuOpener. menu + anchor item are set per right-click by
    // showTrayMenu(). Kept at the root so it survives cell rebuilds.
    TrayMenu {
        id: trayMenu
    }
}