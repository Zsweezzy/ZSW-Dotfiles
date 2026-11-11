// plugins/clock/Widget.qml — Clock plugin
//
// A standalone clock widget that can be used in any bar layout.
// Extends the existing Module component pattern.
//
// Plugin manifest (plugins/clock/manifest.json) specifies:
//   type: "bar-pill", position: "center"

pragma Singleton

import QtQuick 2.15
import Quickshell 0.3

Module {
    id: root
    
    // ===== Plugin Metadata =====
    readonly property string pluginId: "clock"
    readonly property string pluginVersion: "1.0.0"
    
    // ===== Visual Properties =====
    text: ""
    fg: Tokyo.fg
    hoverStyle: true  // Pill changes on hover
    tooltip: "Click to open clock details"
    
    // ===== Time State =====
    property var now: new Date()
    property bool showSeconds: true
    property bool showDate: true
    
    Timer {
        interval: showSeconds ? 1000 : 60000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }
    
    // ===== Layout =====
    implicitHeight: Tokyo.pillHeight
    implicitWidth: label.implicitWidth + hPad * 2
    
    // ===== Content =====
    Text {
        id: label
        anchors.centerIn: parent
        text: {
            const time = Qt.strftime("%H:%M", root.now)
            if (showSeconds) {
                const sec = root.now.getSeconds()
                return time + (sec < 10 ? ":0" : ":") + sec
            }
            return time
        }
        color: root.fg
        font {
            family: Tokyo.fontFamily
            pixelSize: Tokyo.fontSize
            letterSpacing: 0.2
        }
    }
    
    // ===== Mouse Handling =====
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: {
            if (button === Qt.LeftButton) {
                // Signal to open flyout
                root.clicked(button)
            }
        }
    }
    
    // ===== Plugin Events =====
    signal clockClicked(int button)
    signal settingsRequested()
    
    onClicked: button => {
        if (button === Qt.LeftButton) {
            clockClicked(button)
        } else if (button === Qt.RightButton) {
            settingsRequested()
        }
    }
}