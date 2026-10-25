# ZSW-Quickshell

Quickshell configs for this desktop. One folder per bar variant; the colour
theme is chosen by `theme`, not by the folder name.

| Folder | What it is |
|---|---|
| `Tokyonight full/` | Full bar: media, weather, notifications, settings flyout, phone audio |
| `Tokyonight lite/` | Compact bar: workspaces, clock, system, audio, launcher/island |
| `theme-picker/` | Theme picker card, opened from the bar (`SUPER+SHIFT+T`) |

## Run

Quickshell resolves configs as `~/.config/quickshell/<name>/shell.qml`, so the
folder path is the config name:

```bash
quickshell -c "ZSW-Quickshell/Tokyonight lite"    # default session bar
quickshell -c "ZSW-Quickshell/Tokyonight full"
quickshell -c "ZSW-Quickshell/theme-picker"
```

The session starts the lite bar from `~/.config/hypr/hyprland.lua`.
`~/.local/bin/theme` writes `Tokyonight lite/ThemeColors.qml` when the palette
changes; do not edit that file by hand.
