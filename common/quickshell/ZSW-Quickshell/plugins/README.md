# Plugins Directory

Each plugin lives in its own subdirectory with a standard structure:

```
plugin-name/
├── manifest.json     # Plugin metadata (required)
├── Widget.qml        # Main QML component (required)
├── Flyout.qml        # Optional flyout panel
├── scripts/          # Optional scripts for this plugin
└── assets/           # Optional assets (images, etc.)
```

## Creating a Plugin

1. Copy `template/` directory
2. Rename the folder
3. Edit `manifest.json`
4. Implement `Widget.qml`
5. Add optional `Flyout.qml` if needed

## Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique plugin identifier |
| `version` | Yes | Semantic version (e.g., "1.0.0") |
| `entry` | Yes | Entry point QML file (usually "Widget.qml") |
| `type` | Yes | One of: `bar-pill`, `flyout`, `panel`, `overlay`, `service` |
| `description` | Yes | Human-readable description |
| `position` | No | For bar-pill: `left`, `center`, `right` |
| `tags` | No | Array of keywords for categorization |

## Plugin Types

### bar-pill
Widgets on the bar (Clock, Audio, Sys, Workspaces)

### flyout
Popup panels (ClockFlyout, AudioFlyout, SettingsFlyout)

### panel
Control center sections (QuickPanel content)

### overlay
Full-screen overlays (Notification center, Lock screen)

### service
Background daemons (idle daemon, clipboard service)

## Design Requirements

- **Never use literal colors** - use `Tokyo.*` tokens
- **Use 4-space indentation** - `grep -cP '\t'` should be 0
- **Extend Module** for pills, `PopupWindow` for flyouts
- **Define `clicked(int button)`** signal handler
- **Provide `tooltip`** property for hover info