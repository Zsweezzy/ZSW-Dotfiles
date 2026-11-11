// plugins/workspaces/Widget.qml — Workspaces Plugin
//
// Shows workspace numbers on the bar with active state highlighting.
// Extends Module for pill-style appearance.

pragma Singleton

import QtQuick 2.15
import Quickshell 0.3
import Quickshell.Hyprland 0.3

Module {
    id: root
    
    readonly property string pluginId: "workspaces"
    
    // ===== Visual Properties =====
    text: ""  // Dynamically set to current workspace
    fg: Tokyo.bg
    bg: active ? Tokyo.blue : Tokyo.pillBg
    hoverStyle: true
    
    // ===== State =====
    readonly property bool active: Hyprland.activeWorkspace && 
        Hyprland.activeWorkspace.id === Hyprland.monitorAt(screen)?.activeWorkspace?.id
    readonly property int currentWorkspace: active ? Hyprland.activeWorkspace.id : 1
    readonly property var screen: Hyprland.focusedMonitor  // Set by host
    
    // ===== Appearance =====
    readonly property int maxWorkspaces: 10
    readonly property bool showNumbers: true  // False = dots
    
    implicitHeight: Tokyo.pillHeight
    implicitWidth: text.length * 8 + Tokyo.pillHPad * 2
    
    // ===== Content =====
    Text {
        id: pillLabel
        anchors.centerIn: parent
        text: showNumbers ? String(currentWorkspace) : ""
        color: root.active ? "white" : root.fg
        font {
            family: Tokyo.fontFamily
            pixelSize: Tokyo.fontSize
            letterSpacing: 1.2
            bold: root.active
        }
    }
    
    // ===== Mouse Handling =====
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: {
            if (button === Qt.LeftButton) {
                // Cycle through workspaces or focus a specific one
                root.workspaceSelected(currentWorkspace)
            } else if (button === Qt.RightButton) {
                // Show context menu
                root.showWorkspaceMenu()
            }
        }
    }
    
    // ===== Signals =====
    signal workspaceSelected(int workspaceId)
    signal showWorkspaceMenu()
    signal nextWorkspaceRequested()
    signal prevWorkspaceRequested()
    
    // ===== Plugin API =====
    function focus(n) {
        if (n < 1 || n > maxWorkspaces) return
        Hyprland.dispatch("workspace", String(n))
    }
}