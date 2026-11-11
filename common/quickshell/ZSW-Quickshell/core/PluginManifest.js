// PluginManifest.js — plugin manifest loader
//
// This script handles plugin manifest parsing and validation.
// Include in QML via Qt.import.

function parseManifest(path) {
    try {
        const file = Qt.openReadFile(path)
        if (!file) return null
        const text = file.read()
        const json = JSON.parse(text)
        
        // Validate required fields
        const required = ['name', 'version', 'entry', 'type', 'description']
        for (const field of required) {
            if (!json[field]) {
                console.error(`Manifest missing required field: ${field}`)
                return null
            }
        }
        
        // Validate type
        const validTypes = ['bar-pill', 'flyout', 'panel', 'overlay', 'service']
        if (!validTypes.includes(json.type)) {
            console.error(`Invalid plugin type: ${json.type}`)
            return null
        }
        
        return json
    } catch (e) {
        console.error(`Failed to parse manifest ${path}:`, e)
        return null
    }
}

function validateDependencies(manifest, loadedPlugins) {
    if (!manifest.requires) return true
    for (const dep of manifest.requires) {
        if (!loadedPlugins[dep]) {
            console.error(`Missing dependency: ${dep}`)
            return false
        }
    }
    return true
}

function getPluginVersion(manifest) {
    return manifest.version || '0.0.0'
}