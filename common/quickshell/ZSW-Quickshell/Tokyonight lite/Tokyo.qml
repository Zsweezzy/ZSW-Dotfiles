pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property color bgDark: ThemeColors.bgDark
    readonly property color bgHighlight: ThemeColors.bgHighlight
    readonly property color fg: ThemeColors.fg
    readonly property color blue: ThemeColors.blue
    readonly property color cyan: ThemeColors.cyan
    readonly property color green: ThemeColors.green
    readonly property color magenta: ThemeColors.magenta
    readonly property color red: ThemeColors.red

    // ---------- flyout surfaces ----------
    readonly property color panelFill: ThemeColors.panelFill
    readonly property color paneEdge: ThemeColors.paneEdge
    /// "dimmed", for secondary text
    readonly property color dim: ThemeColors.dim

    readonly property color pillBg: Qt.rgba(ThemeColors.bgHighlight.r, ThemeColors.bgHighlight.g, ThemeColors.bgHighlight.b, 0.9)
    readonly property color activeTint: Qt.rgba(ThemeColors.blue.r, ThemeColors.blue.g, ThemeColors.blue.b, 0.2)

    // ---------- motion ----------
    // Rescale beats. The capsule and the launcher card live in different
    // windows, so they share these numbers instead of each inventing one.
    readonly property int expandDuration: 220
    readonly property int collapseDuration: 160
    /// Island flyout sliding out from under the capsule, one value per open.
    readonly property int flyoutDuration: 190

    readonly property real barHeight: 34
    readonly property real pillHeight: barHeight - 8
    readonly property int pillRadius: 10
    // Drop shadow under the floating pills. The shadow needs room outside the
    // pill, so Bar.qml grows its surface by shadowPad while exclusiveZone stays
    // barHeight — the window does not move, only the transparent margin exists.
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.35)
    readonly property real shadowBlur: 12
    readonly property real shadowOffsetY: 3
    readonly property real shadowPad: 12
    // ---------- dynamic island ----------
    // One capsule holds the whole bar (saneAspect's look), in Tokyo Night's own
    // bg_dark rather than his pure black — black next to #16161e windows read as
    // a different, colder palette.
    readonly property color islandFill: ThemeColors.islandFill
    readonly property color islandDim: Qt.rgba(ThemeColors.fg.r, ThemeColors.fg.g, ThemeColors.fg.b, 0.45)
    readonly property real islandHeight: 30
    readonly property real islandPadH: 14
    /// Gap between the pills inside the capsule.
    readonly property real islandGap: 14
    readonly property int islandPanelRadius: 22
    // Flyout card padding and row gap. Panels declare only their own width;
    // these keep a new panel from inventing another 16/12.
    readonly property real panelPadH: 16
    readonly property real panelPadV: 16
    readonly property real panelGap: 12
    // The launcher card is this wide; the capsule widens to it while the
    // launcher is open so the card's square top corners join the capsule's
    // square bottom edge into one shape.
    readonly property real launcherWidth: 340
    // The polkit card is this wide; the capsule widens to it while a prompt
    // is up, same join as the launcher.
    readonly property real polkitWidth: 400
    // The picker panel is this wide (two 190px cards plus gaps and padding);
    // the capsule widens to it while the picker is open for the same reason.
    // shortcut: fixed to two themes, update both widths when a third lands.
    readonly property real pickerWidth: 432
    // Standalone floating slabs only (the toast card): free-floating shapes
    // read as a drifted bar fragment at the bar's own radius of 10.
    readonly property int popupRadius: 20
    readonly property real pillHPad: 12
    readonly property real wsPad: 10
    readonly property real moduleMarginH: 3
    readonly property real pillGap: 6 + moduleMarginH * 2
    readonly property real edgeGap: 6
    readonly property real barShiftV: 2
    // moonsettings' flyout width (FLYOUT_W in its src/app.rs). Bar.qml's
    // top-edge hover strip is this wide and centred so the pointer is over the
    // panel the instant it opens; a strip as wide as the bar would open it from
    // a point the panel does not cover, and its leave-to-dismiss rule then fires
    // with the pointer never having been inside.
    readonly property real flyoutWidth: 1100

    readonly property string fontFamily: "JetBrains Mono Nerd Font"
    readonly property real fontSize: 13

    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/ZSW-Quickshell/Tokyonight lite/scripts"
}
