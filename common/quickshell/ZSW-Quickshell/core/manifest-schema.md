# Plugin Manifest Schema

Each plugin directory contains a `manifest.json` that describes the plugin:

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier (use hyphens, lowercase) |
| `version` | string | Semantic version (e.g., "1.0.0") |
| `entry` | string | Path to main QML file relative to plugin dir |
| `type` | string | One of: `"bar-pill"`, `"flyout"`, `"panel"`, `"overlay"`, `"service"` |
| `description` | string | Human-readable description |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `position` | string | For `bar-pill`: `"left"`, `"center"`, `"right"` |
| `tags` | string[] | Keywords for grouping/searching |
| `dependencies` | string[] | Other plugins this requires (by name) |
| `provides` | string[] | IPC endpoints this plugin exposes |
| `scripts` | object | Map script names to script file paths |

## Example

```json
{
  "name": "workspaces",
  "version": "1.0.0",
  "entry": "Widget.qml",
  "type": "bar-pill",
  "position": "left",
  "tags": ["navigation", "hyprland"],
  "description": "Workspace switcher with numbered pills"
}
```

## Plugin Types

- **bar-pill**: A widget that appears on the bar (like Clock, Audio, Sys)
- **flyout**: A popup panel anchored to a bar-pill or other item
- **panel**: A control center panel with multiple sections
- **overlay**: Full-screen or partial overlays (lock screen, notification center)
- **service**: Background services (daemons, IPC handlers)