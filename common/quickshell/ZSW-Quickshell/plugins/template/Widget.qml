// plugins/template/Widget.qml — template for new plugins
//
// Copy this directory and rename to create a new plugin.
// Edit manifest.json and Widget.qml as needed.

pragma Singleton

import QtQuick 2.15
import Quickshell 0.3

Module {
    id: root
    
    // ===== Plugin API =====
    // These properties are set by the host/bar
    // Flyout that should open when pill is clicked
    property var flyoutHost: null
    
    // Tooltip popup for hover info
    property var tooltipHost: null
    
    // Shared services (if needed)
    // property var networkMonitor: null
    // property var brightness: null
    // property var notifications: null
    
    // ===== Visual Properties =====
    text: "NEW PLUGIN"
    fg: Tokyo.fg
    hoverStyle: true  // Make pill change on hover
    tooltip: "Click to open plugin settings"
    
    // ===== Events =====
    signal clicked(int button)
    signal doubleClicked()
    signal rightClicked()
    
    // ===== Event Handlers =====
    onClicked: {
        if (button === Qt.LeftButton && flyoutHost) {
            flyoutHost.toggleFor(root)
            return
        }
        if (button === Qt.RightButton) {
            // Handle right-click (context menu, etc.)
            return
        }
    }
    
    // ===== Plugin Lifecycle =====
    function initialize() {
        // Called once when plugin is first loaded
        console.log("Template plugin initialized")
    }
    
    function shutdown() {
        // Called when plugin is being unloaded
        console.log("Template plugin shutdown")
    }
    
    // ===== Component Lifecycle =====
    Component.onCompleted: {
        initialize()
    }
}