import QtQuick
import QtQuick.Layouts
import Quickshell

Variants {
    id: barRoot
    model: Quickshell.screens

    /// the shell-wide notification daemon (NotificationStore.qml), shared by
    /// every bar window — one server, one signal source, N toasts
    property var notifications: null

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        anchors { top: true; left: true; right: true }
        implicitHeight: Tokyo.barHeight
        exclusiveZone: Tokyo.barHeight
        color: "transparent"

        // ---------- top-edge hover → moonsettings flyout ----------
        // The monitor's top border is a hot zone: hovering the first 4px of the
        // bar opens the moonsettings flyout, a layer-surface panel that slides
        // down from above. The pills sit at y 6..32 (pillMarginV 4 + barShiftV 2
        // on a 34px bar), so the strip is clear of every pill and takes no hover
        // the bar wanted. It is a HoverHandler, not a MouseArea: hover only, so
        // a click in the band still falls through. `execDetached` never blocks
        // the shell, and `win.screen.name` targets the screen this bar is on.
        //
        // Centred and exactly as wide as the panel, not left-to-right across the
        // bar: the flyout dismisses itself when the pointer leaves it, so a
        // hover starting outside the panel's own span would open it with the
        // pointer already outside and it would vanish on the first move.
        Item {
            id: topEdgeTrigger
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: Tokyo.flyoutWidth
            height: 4
            HoverHandler {
                onHoveredChanged: if (hovered)
                    Quickshell.execDetached(["moonsettings", "flyout", win.screen.name])
            }
        }

        Tooltip { id: tip }

        // The toasts have no pill to hang off, and Quickshell 0.3.1's
        // PopupWindow can only place itself against an anchor item, so this
        // is the marker they aim at: zero-sized, in the bar's top-right
        // corner, clear of the bar itself. Its own size is never drawn.
        Item {
            id: toastAnchor
            anchors {
                top: parent.top; right: parent.right
                topMargin: Tokyo.barHeight + 8; rightMargin: Tokyo.edgeGap + 3
            }
            width: 0
            height: 0
        }

        // One per window so a toast lands on the monitor you are looking at.
        Toast {
            store: barRoot.notifications
            anchorItem: toastAnchor
        }

        RowLayout {
            anchors { left: parent.left; leftMargin: Tokyo.edgeGap; verticalCenter: parent.verticalCenter; verticalCenterOffset: Tokyo.barShiftV }
            spacing: Tokyo.pillGap

            Workspaces {
                screen: win.screen
                Layout.alignment: Qt.AlignVCenter
            }
            Audio {
                tooltipHost: tip
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: Tokyo.barShiftV }
            spacing: Tokyo.pillGap

            Clock {
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            anchors { right: parent.right; rightMargin: Tokyo.edgeGap; verticalCenter: parent.verticalCenter; verticalCenterOffset: Tokyo.barShiftV }
            spacing: Tokyo.pillGap

            Sys {
                tooltipHost: tip
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
