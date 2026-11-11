// PluginManifest.qml — schema for plugin.json
//
// Plugins are registered via manifest.json in their folder:
//
// {
//   "name": "clock",
//   "version": "1.0.0",
//   "entry": "Widget.qml",           // required: main QML component
//   "type": "bar-pill",              // or "flyout", "panel", "overlay"
//   "position": "center",            // for bar-pill: "left", "center", "right"
//   "tags": ["time", "utility"],     // optional tags for grouping
//   "dependencies": [],              // optional plugin names this depends on
//   "ipc": {                         // optional IPC endpoints
//     "toggle": "clock.toggle",
//     "read": "clock.time"
//   },
//   "scripts": {                     // optional script mappings
//     "sync": "scripts/clock.sh"
//   }
// }

pragma Singleton

import QtQuick

Item {
    // This file documents the manifest schema
    // Actual manifests are JSON files, not QML
}