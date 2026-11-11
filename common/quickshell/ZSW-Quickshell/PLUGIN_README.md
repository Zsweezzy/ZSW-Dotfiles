# ZSW-Quickshell Plugin System

## Quick Start

Your quickshell configuration is now organized as a plugin system!

### What's New

```
ZSW-Quickshell/
├── plugins/               # All widgets as plugins
│   ├── clock/            # Clock widget plugin
│   │   ├── manifest.json # Plugin metadata
│   │   └── Widget.qml    # Plugin component
│   └── clock-flyout/     # Clock flyout plugin
├── core/                 # Plugin system infrastructure
│   ├── PluginLoader.qml  # Component loader
│   └── manifest-schema.md # Manifest format
├── shell-lite-plugin.qml # Example config using plugins
├── shell-full-plugin.qml # Full bar config using plugins
└── PLUGIN_README.md      # This file
```

## Plugin Manifest Format

Each plugin folder contains `manifest.json`:

```json
{
  "name": "clock",
  "version": "1.0.0",
  "type": "bar-pill",
  "position": "center",
  "tags": ["time", "utility"],
  "description": "Clock widget showing time with clickable flyout"
}
```

### Plugin Types

| Type | Extends | Example |
|------|---------|---------|
| `bar-pill` | `Module` | Clock, Audio, Sys |
| `flyout` | `PopupWindow` | ClockFlyout, AudioFlyout |
| `panel` | `Item` | QuickPanel, SettingsPanel |
| `overlay` | `Item` | NotificationCenter, LockScreen |
| `service` | `Item` | Idle, Clipboard, PolkitAgent |

## Creating a New Plugin

1. **Create the plugin directory:**
   ```bash
   mkdir -p plugins/my-widget
   ```

2. **Create manifest.json:**
   ```json
   {
     "name": "my-widget",
     "version": "1.0.0",
     "type": "bar-pill",
     "position": "right",
     "description": "My awesome widget"
   }
   ```

3. **Create Widget.qml:**
   ```qml
   import QtQuick 2.15
   import Quickshell 0.3
   
   Module {
       text: "NEW"
       fg: Tokyo.fg
       hoverStyle: true
       
       signal clicked(int button)
       onClicked: console.log("Clicked!")
   }
   ```

4. **Reference in shell config:**
   ```qml
   Component {
       id: myWidget
       source: "plugins/my-widget/Widget.qml"
   }
   ```

## Using Plugins in Shell Config

```qml
ShellRoot {
    // Services
    NotificationStore { id: notificationStore }
    
    // Plugin components
    Component { id: clock; source: "plugins/clock/Widget.qml" }
    Component { id: clockFlyout; source: "plugins/clock-flyout/Widget.qml" }
    
    Bar {
        // Inject services
        notifications: notificationStore
        
        Clock {
            sourceComponent: clock
            flyoutHost: clockFlyout
        }
    }
}
```

## API Reference

### Module (bar-pill base)

```qml
Module {
    property string text: ""
    property color fg: Tokyo.fg
    property bool hoverStyle: false
    property var flyoutHost: null
    signal clicked(int button)
}
```

### PopupWindow (flyout base)

```qml
PopupWindow {
    property Item anchorItem: null
    width: 300
    modal: false
    closeOnOutsideClick: true
}
```

## Design Tokens (Tokyo.qml)

Always use design tokens - never literal colors:

| Token | Use |
|-------|-----|
| `Tokyo.fg` | Primary text |
| `Tokyo.bg` | Surface fill |
| `Tokyo.pillBg` | Bar pill background |
| `Tokyo.pillHeight` | Bar pill height |
| `Tokyo.pillRadius` | Bar pill corner radius |
| `Tokyo.fontSize` | Base font size |
| `Tokyo.fontFamily` | Font family |
| `Tokyo.pillGap` | Gap between pills |

## Plugin Communication

### Service Injection

Services are declared in ShellRoot and passed to widgets:

```qml
ShellRoot {
    NotificationStore { id: notifications }
    
    Bar {
        notifications: notifications  // Inject
    }
}
```

### Signals

```qml
Module {
    signal toggleFlyout()
    
    onClicked: toggleFlyout()
}
```

### IPC

```qml
ShellRoot {
    IpcHandler {
        target: "clock"
        function toggle(): void { /* ... */ }
    }
}
```

## Migration

To convert existing widgets:

1. Copy the QML file to `plugins/<name>/Widget.qml`
2. Create `manifest.json`
3. Update shell config to use `sourceComponent`

## Examples

See `plugins/clock/` and `plugins/clock-flyout/` for complete working examples.