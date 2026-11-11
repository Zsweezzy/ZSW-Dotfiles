// PluginLoader.qml — plugin discovery and loading
//
// Usage in shell.qml:
//   PluginLoader {
//       id: plugins
//       basePath: Quickshell.configDir + "/ZSW-Quickshell/plugins/"
//       
//       // Access loaded plugins:
//       Component { sourceComponent: plugins.getComponent("clock") }
//   }
//
// Properties:
//   basePath - directory containing plugin folders
//   plugins - map of plugin name -> { component, manifest }
//
import QtQuick 2.15

Item {
    id: root
    
    // Configuration
    property string basePath: ""
    property string[] pluginPaths: ["plugins/"]
    
    // Loaded plugins
    property var plugins:({})
    property var components:({})
    
    // Convenience lists by type
    property var barPills: []
    property var flyouts: []
    property var panels: []
    property var overlays: []
    property var services: []
    
    signal ready()
    signal error(string plugin, string message)
    
    // Get plugin by name
    function get(name) {
        return plugins[name] ?? null
    }
    
    // Get component by name
    function getComponent(name) {
        return components[name] ?? null
    }
    
    // Get manifest by name
    function getManifest(name) {
        if (name in plugins) return plugins[name].manifest
        return null
    }
    
    // Check if plugin exists
    function has(name) {
        return name in plugins
    }
    
    // List all plugin names
    function list() {
        return Object.keys(components)
    }
    
    // Get plugins by type
    function getByType(type) {
        const lists = {
            "bar-pill": barPills,
            "flyout": flyouts,
            "panel": panels,
            "overlay": overlays,
            "service": services
        }
        return lists[type] || []
    }
    
    // Scan and load all plugins
    function loadAll() {
        plugins = {}
        components = {}
        barPills = []
        flyouts = []
        panels = []
        overlays = []
        services = []
        
        const baseDir = basePath
        if (!baseDir) return ready()
        
        // Get directory entries
        const entries = []
        try {
            // Use Quickshell's file API if available
            if (typeof Quickshell !== 'undefined' && Quickshell.fileList) {
                const result = Quickshell.fileList({ path: baseDir })
                if (result && result.entries) {
                    entries.push(...result.entries)
                }
            } else {
                // Fallback: assume directory exists and try to enumerate
                console.log("PluginLoader: basePath =", baseDir)
            }
        } catch (e) {
            console.error("Plugin scan failed:", e)
            return ready()
        }
        
        // Process each plugin directory
        entries.forEach(entry => {
            if (entry.isDirectory) {
                processPlugin(entry.name, baseDir + "/" + entry.name)
            }
        })
        
        ready()
    }
    
    function processPlugin(name, dir) {
        const manifestPath = dir + "/manifest.json"
        const manifest = tryLoadManifest(manifestPath)
        
        if (!manifest) {
            console.warn("Plugin missing/invalid manifest:", name)
            return
        }
        
        const entryPath = dir + "/" + (manifest.entry || "Widget.qml")
        const component = tryLoadComponent(entryPath)
        
        if (!component) {
            return
        }
        
        plugins[name] = { component: component, manifest: manifest }
        components[name] = component
        
        // Categorize by type
        switch (manifest.type) {
            case "bar-pill": barPills.push(name); break
            case "flyout": flyouts.push(name); break
            case "panel": panels.push(name); break
            case "overlay": overlays.push(name); break
            case "service": services.push(name); break
        }
    }
    
    function tryLoadManifest(path) {
        try {
            const file = Qt.openReadFile(path)
            if (!file) return null
            const text = file.read()
            const json = JSON.parse(text)
            
            // Validate required fields
            if (!json.name || !json.version || !json.entry || !json.type || !json.description) {
                console.error("Manifest missing required fields:", path)
                return null
            }
            
            return json
        } catch (e) {
            console.error("Failed to load manifest:", path, e)
            return null
        }
    }
    
    function tryLoadComponent(path) {
        try {
            const component = Qt.createComponent(path)
            if (component.status === Component.Error) {
                console.error("Component load error:", path, component.errorString)
                error(path, component.errorString)
                return null
            }
            return component
        } catch (e) {
            console.error("Failed to create component:", path, e)
            error(path, e.toString())
            return null
        }
    }
    
    Component.onCompleted: {
        loadAll()
    }
}