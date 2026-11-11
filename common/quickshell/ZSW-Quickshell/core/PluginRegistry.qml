// PluginRegistry.qml — central plugin registry
//
// This is a singleton that manages all loaded plugins.
// Other components get plugins via the registry.

pragma Singleton

import QtQuick

Item {
    id: root
    
    // All loaded plugins: { name: { component, manifest, instance } }
    property var plugins: ({})
    
    // Loaded components: { name: Component }
    property var components: ({})
    
    // Plugin categories
    readonly property var barPills: []
    readonly property var flyouts: []
    readonly property var panels: []
    
    signal registered(string name, var manifest)
    signal error(string plugin, string message)
    
    // Register a plugin
    function register(name, component, manifest) {
        plugins[name] = { component: component, manifest: manifest }
        components[name] = component
        registered(name, manifest)
        categorize(name, manifest)
    }
    
    function unregister(name) {
        delete plugins[name]
        delete components[name]
        recategorize()
    }
    
    function getComponent(name) {
        return components[name] || null
    }
    
    function getManifest(name) {
        return plugins[name]?.manifest || null
    }
    
    function isRegistered(name) {
        return name in plugins
    }
    
    function listPlugins() {
        return Object.keys(plugins)
    }
    
    function listByType(type) {
        switch (type) {
            case "bar-pill": return barPills
            case "flyout": return flyouts
            case "panel": return panels
            default: return []
        }
    }
    
    function categorize(name, manifest) {
        if (manifest.type === "bar-pill") barPills.push(name)
        if (manifest.type === "flyout") flyouts.push(name)
        if (manifest.type === "panel") panels.push(name)
    }
    
    function recategorize() {
        barPills = []
        flyouts = []
        panels = []
        for (const name in plugins) {
            categorize(name, plugins[name].manifest)
        }
    }
}