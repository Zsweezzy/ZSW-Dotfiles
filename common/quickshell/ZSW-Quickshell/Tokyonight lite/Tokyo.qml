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
    /// One step up from the flyout card: the two boxes inside the control
    /// centre sit lighter than islandFill, but darker than the panel itself.
    readonly property color boxFill: Qt.rgba(ThemeColors.bgHighlight.r, ThemeColors.bgHighlight.g, ThemeColors.bgHighlight.b, 0.35)
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
    /// Short: the card is the answer to a click, not a scene change.
    readonly property int flyoutDuration: 130

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
    /// The flyout is a card over app windows, so it casts a heavier shadow
    /// than a bar pill: the pills sit in the bar's own surface, the card has
    /// to separate from whatever is behind it.
    readonly property color flyoutShadowColor: Qt.rgba(0, 0, 0, 0.55)
    readonly property real flyoutShadowBlur: 28
    readonly property real flyoutShadowOffsetY: 12
    /// Transparent room the flyout's popup gives that shadow on the sides and
    /// below. Must cover blur + offset, or the shadow is cut off at the
    /// surface edge and ends in a hard line. None above: the card's top edge
    /// must stay flush under the capsule.
    readonly property real flyoutShadowPad: 44
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
    // moonsettings' flyout width (FLYOUT_W in its src/app.rs). Nothing in this
    // tree reads it any more: the flyout opens from a click or a keybind, not
    // from a pointer sitting over the bar.
    readonly property real flyoutWidth: 1100

    readonly property string fontFamily: "JetBrains Mono Nerd Font"
    readonly property real fontSize: 13

    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/ZSW-Quickshell/Tokyonight lite/scripts"
}
