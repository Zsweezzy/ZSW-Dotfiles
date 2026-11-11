// plugins/clock-flyout/Widget.qml — Clock Flyout Plugin
//
// A popup panel showing detailed clock info, timers, and calendar.
// Opens from the clock pill click.
//
// Plugin manifest (plugins/clock-flyout/manifest.json) specifies:
//   type: "flyout"

pragma Singleton

import QtQuick 2.15
import Quickshell 0.3

PopupWindow {
    id: root
    
    // ===== Plugin Metadata =====
    readonly property string pluginId: "clock-flyout"
    readonly property string pluginVersion: "1.0.0"
    
    // ===== API =====
    /// Set this to the anchor (clock pill) before opening
    property Item anchorItem: null
    property var clockTime: new Date()
    
    width: 320
    implicitHeight: contentArea.implicitHeight + 32
    modal: false
    closeOnOutsideClick: true
    closeOnEscape: true
    
    // ===== Anchors =====
    anchors {
        horizontalCenter: anchorItem?.horizontalCenter
        top: anchorItem?.bottom
        topMargin: anchorItem?.height ? 8 : 40
    }
    
    // ===== Content =====
    Rectangle {
        id: contentArea
        anchors.fill: parent
        color: Tokyo.pane
        border.width: 1
        border.color: Tokyo.paneEdge
        radius: Tokyo.popupRadius
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            // Header
            Text {
                text: "Clock"
                color: Tokyo.fg
                font.family: Tokyo.fontFamily
                font.pixelSize: 16
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            
            // Time display
            Text {
                id: timeDisplay
                text: Qt.strftime("%H:%M:%S", clockTime)
                color: Tokyo.fg
                font.family: Tokyo.fontFamily
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Timer {
                    interval: 1000
                    repeat: true
                    running: true
                    onTriggered: clockTime = new Date()
                }
            }
            
            // Date
            Text {
                text: Qt.strftime("%A, %B %d, %Y", clockTime)
                color: Tokyo.dim
                font.family: Tokyo.fontFamily
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }
            
            // Uptime (placeholder)
            Text {
                text: "Uptime: —"
                color: Tokyo.dim
                font.family: Tokyo.fontFamily
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }
            
            // Footer
            Text {
                text: "Tab to timer, Shift+Tab for date picker"
                color: Tokyo.dim
                font.family: Tokyo.fontFamily
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
                opacity: 0.6
            }
        }
    }
    
    // ===== API Methods =====
    function toggleFor(anchor) {
        anchorItem = anchor
        clockTime = new Date()
        open()
    }
    
    function openAt(anchor, time) {
        anchorItem = anchor
        clockTime = time || new Date()
        open()
    }
}