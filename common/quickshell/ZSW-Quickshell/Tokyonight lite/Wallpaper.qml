import QtQuick
import Quickshell
import Quickshell.Wayland

// hyprpaper used to paint the desktop. A background-layer surface per monitor
// does the same: the theme script writes the palette's wallpaper path into
// ThemeColors.qml, whose reload repaints every screen.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        required property ShellScreen modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        // Behind everything, including windows: the compositor's own backdrop.
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        color: "black"

        Image {
            anchors.fill: parent
            // hyprpaper's fit_mode = cover.
            fillMode: Image.PreserveAspectCrop
            source: ThemeColors.wallpaper
            asynchronous: true
            cache: true
        }
    }
}
