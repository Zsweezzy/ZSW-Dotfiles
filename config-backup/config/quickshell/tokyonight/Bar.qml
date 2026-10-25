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
