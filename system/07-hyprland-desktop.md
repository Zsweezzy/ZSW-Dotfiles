# 07 — Hyprland desktop

Version: **Hyprland 0.56.2**, config language: **Lua** (`hl.*` API, not the classic
`hyprland.conf` syntax).

Config file: `/home/maxii/.config/hypr/hyprland.lua`.

## Important operational facts learned

- **`hyprctl keyword` does not work with the Lua parser.** Use `hyprctl eval` with the
  `hl.*` API instead (`hl.monitor(...)`, `hl.config(...)`, `hl.animation(...)` were
  verified working).
- `hyprctl configerrors` returning **empty** is the reliable validation signal.
  `hyprctl getoption` does not expose every option in this build (no `misc:vfr`, no
  `misc:damage_tracking`; animation leaves are not queryable by
  `animation:<leaf>:<key>`).
- `hyprctl reload` **is safe** in this config. Its own comment in the Lua file states
  that reload rebuilds from fresh Lua state in a single pass and does **not** re-fire
  `hyprland.start`.
- Hyprland 0.56.2 executes the config file **twice at startup**, so every `hl.bind` lands
  in the bind list twice. The config works around this with a
  `sleep 2 && hyprctl reload` at the end of `hyprland.start` (documented in-file).

## What was changed on 2026-10-14 — "keep animations, make them snappy"

14 asserted replacements in `hyprland.lua`. Durations were cut roughly **45%** plus a
couple of larger trims. Animations are **still enabled** (`animations:enabled = true`).

| Animation leaf | Before | After |
|----------------|--------|-------|
| global | 10 | 4 |
| border | 5.39 | 3.0 |
| windows | 4.79 | 2.8 |
| windowsIn | 4.1 | 2.4 |
| windowsOut | 1.49 | 1.0 |
| fadeIn | 1.73 | 1.0 |
| fadeOut | 1.46 | 0.9 |
| fade | 3.03 | 1.8 |
| layers / layersIn / layersOut | 0.8 | 0.6 |
| fadeLayersIn / fadeLayersOut | 0.8 | 0.6 |
| workspaces | 1.94 | 1.2 |
| workspacesIn | 1.21 | 0.8 |
| workspacesOut | 1.94 | 1.2 |
| specialWorkspaceIn | 4.79 | 2.6 |
| specialWorkspaceOut | 1.49 | 1.0 |
| zoomFactor | 7 | 3 |

Validation performed:
- `luac -p` -> **SYNTAX OK**
- `hyprctl configerrors` -> **empty**
- `hyprctl reload` -> **ok**
- `animations:enabled` -> **true**

## Border animation: made static

- `borderangle` was set to `enabled = false` with an explanatory comment.
  Reason: the animated gradient border is a continuously-repainting loop; the user chose
  "make the border static, keep everything else snappy".
- **Honesty note:** an A/B measurement of the `borderangle` loop was **inconclusive** —
  see `12-measurements.md`. It could not be measured on a busy session because Firefox /
  YouTube keep the compositor redrawing. The static border is a defensible
  idle-cost/visual choice, **not** a measured FPS win.

## Autostart (from the `hyprland.start` hook in the Lua file)

Active:
- `hyprpaper` — wallpaper daemon
- `quickshell -c tokyonight` — status bar (waybar dotfiles backed up at
  `gh:Zsweezzy/waybar-dotfiles`)
- `/home/maxii/.local/bin/hypr-shortcut-launcher --background`
- scratchpad notepad (`HYPR_SCRATCH ... --background`)
- `wl-paste --type text --watch cliphist store`
- `wl-paste --type image --watch cliphist store`
- `/home/maxii/.local/bin/neru launch`
- `hyprpm reload -nn`
- `systemctl --user start hyprpolkitagent` — polkit auth prompts
- `hypr-session autosave-loop` — session state autosave (flock-guarded)
- `sleep 2 && hyprctl reload` — the 0.56.2 double-load workaround

Disabled (commented out in-file, deliberately):
- `openrgb --startminimized` (OpenRGB still autostarts via XDG autostart)
- `systemctl --user start apollo` (Moonlight gamestream — start on demand)
- `opendeck --hide`

On exit (`hyprland.shutdown`-style hook): `hypr-session save`.

Note: because autostart runs with a minimal environment, absolute paths are used for
local binaries on purpose.

## Idle-cost items in the desktop

- `quickshell` (the bar) holds ~**107 MB** RSS. That is the largest desktop-owned
  process and is the price of the custom bar; it is not something to "fix" unless the
  user wants a lighter bar.
- `mako` (notifications) ~22 MB, `pipewire` ~39 MB, `Hyprland` itself ~143 MB.
- Two `wl-paste --watch` processes exist to feed cliphist; negligible CPU, needed for
  clipboard history.
