# ZSW-Quickshell Plugin System

## Overview

This plugin system provides a modular architecture for your Quickshell configuration. Each widget (pill, flyout, panel, etc.) lives as an independent plugin, making your shell easily extensible and composable.

## Architecture

```
ZSW-Quickshell/           # Plugin system root
├── plugins/              # All widget plugins
│   ├── clock/            # Clock widget plugin
│   │   ├── manifest.json
│   │   └── Widget.qml
│   ├── workspaces/
│   ├── audio/
│   ├── sys/
│   └── ...
├── core/                 # Plugin system infrastructure
│   └── PluginLoader.qml  # Discovers and instantiates plugins
├── Tokyo.qml             # Design tokens (shared)
└── shell-lite.qml        # Example config using plugins
```

## Plugin Types

| Type | Extends | Use Case | File |
|------|---------|----------|------|
| `bar-pill` | `Module` | Widgets on the bar | `plugins/name/Widget.qml` |
| `flyout` | `PopupWindow` | Pop-up panels | `plugins/name/Flyout.qml` |
| `panel` | `Item` | Control center sections | `plugins/name/Panel.qml` |
| `overlay` | `Item` | Full-screen overlays | `plugins/name/Overlay.qml` |
| `service` | `Item` | Background processes | `plugins/name/Service.qml` |

## Manifest Format

Each plugin has a `manifest.json`:

```json
{
  "name": "clock",
  "version": "1.0.0",
  "type": "bar-pill",
  "position": "center",
  "tags": ["time", "utility"],
  "provides": ["toggleFlyout"],
  "description": "Clock widget showing time and date",
  "dependencies": []
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Plugin identifier, used as QML file prefix |
| `version` | Yes | Semantic version |
| `type` | Yes | One of the 5 types above |
| `position` | For bar-pill | `left`, `center`, or `right` |
| `tags` | No | For categorization |
| `provides` | No | IPC endpoints this plugin exposes |
| `dependencies` | No | Other plugins this needs |
| `description` | Yes | Human-readable description |

## Using Plugins in Shell Config

```qml
ShellRoot {
    // Shared services (one instance each)
    NotificationStore { id: notifications }
    NetworkMonitor { id: net }
    Brightness { id: brightness }
    
    // Load plugin components
    Component { id: clockWidget; source: "plugins/clock/Widget.qml" }
    Component { id: audioWidget; source: "plugins/audio/Widget.qml" }
    
    Bar {
        // Inject services
        notifications: notifications
        networkMonitor: net
        brightness: brightness
        
        // Left side pips
        Workspaces { sourceComponent: workspacesWidget }
        Audio { sourceComponent: audioWidget }
        
        // Center
        Clock { sourceComponent: clockWidget }
        
        // Right side
        Sys { }
        NotificationBell { store: notifications }
        Settings { }
    }
}
```

## Creating a Plugin

### 1. Create Directory

```bash
mkdir -p plugins/my-new-widget
```

### 2. Create Manifest

```json
{
  "name": "my-new-widget",
  "version": "1.0.0",
  "type": "bar-pill",
  "position": "right",
  "description": "My new widget"
}
```

### 3. Create Widget.qml

```qml
import QtQuick 2.15
import Quickshell 0.3

Module {
    id: root
    
    // Visual properties
    text: "NEW"
    fg: Tokyo.fg
    hoverStyle: true
    
    // Events
    signal clicked(int button)
    
    onClicked: {
        if (button === Qt.LeftButton) {
            // Handle click
        }
    }
}
```

## Plugin Communication

### Service Injection

Services are declared in `ShellRoot` and passed to widgets:

```qml
// In ShellRoot
NotificationStore { id: notificationStore }

// In widget
Module {
    property var notifications: notificationStore  // Set by host
    onClicked: {
        // Access notifications.store.unread
    }
}
```

### Signals

Widgets can emit signals the shell or other widgets connect to:

```qml
Module {
    signal toggleFlyout()
    signal updateRequested()
    
    onClicked: toggleFlyout()
}
```

## Design Requirements

Always use design tokens from `Tokyo.qml`:

| Token | Use |
|-------|-----|
| `Tokyo.fg` | Primary text color |
| `Tokyo.bg` | Surface fill |
| `Tokyo.pillBg` | Bar pill background |
| `Tokyo.pillHeight` | Bar pill height |
| `Tokyo.pillRadius` | Bar pill corner radius |
| `Tokyo.fontSize` | Base font size |
| `Tokyo.fontFamily` | Font family |
| `Tokyo.pillGap` | Gap between pills |

Never use literal colors like `#1e2030`.

## Migration Guide

To convert an existing widget to a plugin:

1. Copy the QML file to `plugins/<name>/Widget.qml`
2. Ensure it extends `Module` or appropriate base type
3. Create `manifest.json`
4. Update `shell.qml` to use `sourceComponent`

Example: Converting `Tokyonight full/Clock.qml` → `plugins/clock/Widget.qml`

## Example Plugins

### Clock (plugins/clock)

Shows time and date, opens flyout on click.

### Workspaces (plugins/workspaces)

Shows workspace numbers, highlights active.

### Audio (plugins/audio)

Shows volume, opens audio control flyout.

### Sys (built-in)

Combined GPU/CPU/RAM widget.