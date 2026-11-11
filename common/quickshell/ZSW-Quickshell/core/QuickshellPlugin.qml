// QuickshellPlugin.qml — base component for all plugins
//
// All bar-pill, flyout, panel, overlay, and service plugins
// should extend this base class for consistency.

import QtQuick 2.15

Item {
    id: root
    
    // ===== Plugin Identity =====
    /// Unique plugin identifier (set by shell)
    readonly property string pluginId: ""
    
    /// Plugin version from manifest
    readonly property string pluginVersion: "0.0.0"
    
    /// Human-readable description from manifest
    readonly property string pluginDescription: ""
    
    // ===== Shell Lifecycle =====
    /// Called when plugin is loaded by the shell
    function pluginInitialize() {}
    
    /// Called when plugin is about to be unloaded
    function pluginShutdown() {}
    
    /// Called when the host shell configuration changes
    function pluginReconfigure(config) {}
    
    // ===== Visual Properties =====
    /// Background color (tokens from Tokyo.qml)
    property color bgColor: Tokyo?.bg
    
    /// Foreground/text color
    property color fgColor: Tokyo?.fg
    
    /// Accent color (varies by widget type)
    property color accentColor: Tokyo?.cyan
    
    // ===== State =====
    /// Whether the plugin has been initialized
    readonly property bool initialized: false
    
    // ===== Events =====
    signal pluginReady()
    signal pluginError(string message)
    
    // ===== Utility =====
    function log(message) {
        console.log(`[${pluginId || "unknown"}] ${message}`)
    }
    
    function error(message) {
        console.error(`[${pluginId || "unknown"}] ${message}`)
        pluginError(message)
    }
}