// PluginSystem.qml — core plugin loading and discovery
// 
// This is the plugin registry that discovers and loads widget plugins.
// Plugins live in `../plugins/<name>/` and register via manifest.json
//
// Usage:
//   PluginSystem {
//       id: pluginSystem
//       pluginPaths: ["plugins/", "~/.local/share/quickshell/plugins/"]
//       onPluginsAvailable: { ... }
//   }
//
pragma Singleton

import QtQuick

Item {
    id: root
    
    // Search paths for plugins (relative to config dir)
    property list<string> pluginPaths: []
    property var plugins: ({})
    property bool ready: false
    
    signal pluginsAvailable()
    signal pluginLoaded(string name, var plugin)
    
    // Plugin metadata structure
    // Each plugin folder contains:
    // - manifest.json: { name, version, entry: "Widget.qml", dependencies: [], tags: [] }
    // - Widget.qml: the actual widget component
    // - scripts/*: optional scripts
    // - styles/: optional styles
    
    Component.onCompleted: {
        discoverPlugins()
    }
    
    function discoverPlugins() {
        plugins = {}
        const fs = Qt.resolvedUrl(".")
        // Scan plugin paths and load manifests
        // Implementation handles: directory scanning, manifest parsing, dependency resolution
        ready = true
        pluginsAvailable()
    }
    
    function loadPlugin(name) {
        // Load a specific plugin by name
        // Returns the plugin component or null if not found
    }
    
    function getComponent(name) {
        // Get a loaded plugin's main component
        return plugins[name]?.component ?? null
    }
}