import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// StatusNotifierItems, inside the capsule. Nothing else on this desktop hosts
// them: swaync is D-Bus activated and quickshell's own tray is the only
// StatusNotifierWatcher, so without this line an app's icon is published to no
// one. Icons are the item's own artwork; there is no style to apply.
Repeater {
    id: root

    /// The bar's window. Tray menus are positioned relative to it.
    property var window: null

    model: SystemTray.items

    delegate: Item {
        id: icon

        required property var modelData

        implicitWidth: 18
        implicitHeight: 18

        Image {
            id: image
            anchors.fill: parent
            source: icon.modelData.icon
            sourceSize: Qt.size(16, 16)
            smooth: true
            visible: status === Image.Ready
        }
        // Some items ship an icon name the theme does not resolve. A dot beats
        // an empty gap that looks like a rendering bug.
        Text {
            anchors.centerIn: parent
            visible: !image.visible
            text: "\uf111"
            color: Tokyo.dim
            font { family: Tokyo.fontFamily; pixelSize: 6 }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true

            onClicked: m => {
                const item = icon.modelData
                if (m.button === Qt.RightButton && item.hasMenu && root.window) {
                    const p = icon.mapToItem(null, 0, 0)
                    item.display(root.window, Math.round(p.x), Math.round(p.y))
                } else if (m.button === Qt.LeftButton) {
                    item.activate()
                } else {
                    item.secondaryActivate()
                }
            }
        }
    }
}
