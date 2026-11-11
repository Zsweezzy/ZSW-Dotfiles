# Plugin System Summary

## What Was Created

A plugin architecture for ZSW-Quickshell that makes your shell configuration modular and extensible.

### New Files

| Location | Description |
|----------|-------------|
| `plugins/` | All widget plugins as separate directories |
| `plugins/clock/` | Clock widget plugin with manifest.json |
| `plugins/clock-flyout/` | Clock flyout plugin |
| `plugins/workspaces/` | Workspace switcher plugin |
| `plugins/template/` | Template for creating new plugins |
| `core/PluginLoader.qml` | Plugin discovery/loading component |
| `core/manifest-schema.md` | Manifest format specification |
| `core/PLUGIN_SYSTEM.md` | Full architecture documentation |
| `core/PLUGIN_README.md` | User guide |
| `shell-lite-plugin.qml` | Example config using the plugin system |

## Plugin Architecture

```
plugins/
├── clock/
│   ├── manifest.json     # {name, version, type, position, tags, description}
│   └── Widget.qml        # Main plugin component
├── clock-flyout/
│   ├── manifest.json
│   └── Widget.qml
├── workspaces/
│   ├── manifest.json
│   └── Widget.qml
└── template/             # Copy this to create new plugins
```

## Manifest Format

```json
{
  "name": "clock",
  "version": "1.0.0",
  "type": "bar-pill",
  "position": "center",
  "tags": ["time", "utility"],
  "description": "Clock widget showing time and date"
}
```

### Type Field Values
- `bar-pill` - Widget pill on the bar (extends Module)
- `flyout` - Popup panel (extends PopupWindow)
- `panel` - Control center section (extends Item)
- `overlay` - Full-screen overlay (extends Item)
- `service` - Background daemon (extends Item)

## Using Plugins

```qml
ShellRoot {
    // Services
    NotificationStore { id: notifications }
    
    // Plugin components
    Component { id: clock; source: "plugins/clock/Widget.qml" }
    Component { id: clockFlyout; source: "plugins/clock-flyout/Widget.qml" }
    
    Bar {
        notifications: notifications
        
        Clock {
            sourceComponent: clock
            flyoutHost: clockFlyout
        }
    }
}
```

## Creating a New Plugin

1. Copy template: `cp -r plugins/template/ plugins/my-new-widget`
2. Edit `manifest.json`
3. Implement `Widget.qml`
4. Reference in shell config

## Design Requirements

**Always use design tokens, never literals:**
- `Tokyo.fg` - Primary text color
- `Tokyo.bg` - Surface fill
- `Tokyo.pillBg` - Bar pill background
- `Tokyo.pillHeight` - Bar pill height
- `Tokyo.pillRadius` - Bar pill radius
- `Tokyo.fontSize` - Base font size
- `Tokyo.fontFamily` - Font family

## Next Steps

1. **Test the plugin system** with `shell-lite-plugin.qml`
2. **Convert remaining widgets** to plugins as needed
3. **Create your own plugins** using the template

## Migration

To convert existing widgets (clock, workspaces, audio, sys, etc.):
1. Copy QML file to `plugins/<name>/Widget.qml`
2. Create `manifest.json`
3. Update shell config to use `sourceComponent`

See `plugins/clock/Widget.qml` for a complete working example.