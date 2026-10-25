pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property color bgDark: "#16161e"
    readonly property color bgHighlight: "#2f334d"
    readonly property color fg: "#c8d3f5"
    readonly property color blue: "#82aaff"
    readonly property color cyan: "#86e1fc"
    readonly property color green: "#9ece6a"
    readonly property color magenta: "#bb9af7"
    readonly property color red: "#f7768e"          // moon red

    // ---------- flyout surfaces ----------
    readonly property color panelFill: "#2f334d"
    readonly property color paneEdge: "#454c65"
    /// "dimmed", for secondary text
    readonly property color dim: "#7983a4"

    readonly property color pillBg: Qt.rgba(0x2f / 255, 0x33 / 255, 0x4d / 255, 0.9)
    readonly property color activeTint: Qt.rgba(0x82 / 255, 0xaa / 255, 0xff / 255, 0.2)

    readonly property real barHeight: 34
    readonly property real pillHeight: barHeight - 8
    readonly property int pillRadius: 10
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

    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/tokyonight/scripts"
}
