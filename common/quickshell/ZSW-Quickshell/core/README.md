# Plugin System for ZSW-Quickshell

## Overview

This plugin system provides a modular architecture for Quickshell configurations, making widgets and features easily extensible and composable.

## Architecture

```
ZSW-Quickshell/
├── plugins/                 # All widget plugins
│   ├── clock/              # Clock widget
│   │   ├── manifest.json   # Plugin metadata
│   │   └── Widget.qml      # Main component
│   ├── clock-flyout/       # Clock flyout
│   └── .../                # More plugins
├── config/                 # Bar configurations (composes plugins)
│   ├── lite-shell.qml      # Lite bar using plugins
│   └── full-shell.qml      # Full bar using plugins
├── core/                   # Plugin system core
│   ├── PluginLoader.qml    # Discovers and loads plugins
│   ├── PluginRegistry.qml  # Central registry
│   └── manifest-schema.md  # Plugin manifest format
└── Tokyo.qml               # Design tokens (shared by all plugins)
```

## Plugin Types

| Type | Description | Location |
|------|-------------|----------|
| `bar-pill` | Widget pill on the bar | Left/Center/Right rail |
| `flyout` | Popup panel anchored to pill | Opens on pill click |
| `panel` | Control center section | Embedded in QuickPanel |
| `overlay` | Full-screen overlay | Modal dialogs |
| `service` | Background daemon | Runs independently |

## Creating a Plugin

1. Create `plugins/<name>/` directory
2. Create `manifest.json`:
```json
{
  "name": "my-widget",
  "version": "1.0.0",
  "entry": "Widget.qml",
  "type": "bar-pill",
  "position": "right",
  "tags": ["utility"],
  "description": "My awesome widget"
}
```

3. Create `Widget.qml`:
```qml
import QtQuick
import Quickshell

Module {
    id: root
    text: "Hello"
    onClicked: console.log("Clicked!")
}
```

## Using Plugins in a Bar

```qml
ShellRoot {
    PluginLoader {
        id: pluginLoader
        basePath: Quickshell.configDir
        
        onPluginsAvailable: {
            // Create pill instances
            barRoot.children = [
                pluginLoader.getComponent("workspaces"),
                pluginLoader.getComponent("clock"),
                pluginLoader.getComponent("sys"),
            ]
        }
    }
    
    Bar {
        // Bar can now dynamically compose plugins
    }
}
```

## Plugin API

| Property | Type | Description |
|----------|------|-------------|
| `flyoutHost` | object | Parent flyout for click-to-open |
| `tooltipHost` | object | Tooltip popup |
| `networkMonitor` | object | Shared network service |
| `brightness` | object | Shared brightness service |

## Service Discovery

Services are loaded once in shell.qml and injected to widgets:

```qml
NotificationStore { id: notificationStore }
NetworkMonitor { id: networkMonitor }  
Brightness { id: brightness }

Bar {
    notifications: notificationStore
    networkMonitor: networkMonitor
    brightness: brightness
}
```

## Migration Guide

See `MIGRATION-GUIDE.md` for converting existing widgets to plugins.