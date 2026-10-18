# dotfiles

Theme configs and one-off tweaks for my Arch/KDE setup.

## Layout

Every theme occupies its own folder at the repo root (`bwzs/`,
`tokyonight-moon/`, `nord/` — `nord` not created yet). Instead of one raw
`.config`/`.local` mirror, each theme is split into **component folders**
(named after the app/system that owns the config). The component folder
**is** the app folder — config files sit directly inside it, so applying
is always a clean drag-and-drop:

```
~/.config/kitty/kitty.conf          -> bwzs/kitty/kitty.conf
~/.config/kdeglobals                -> bwzs/kde/kdeglobals
~/.config/plasma-org.kde…appletsrc  -> bwzs/plasma/plasma-org.kde…appletsrc
~/.local/share/plasma/desktoptheme  -> bwzs/plasma/desktoptheme
~/.local/share/wallpapers           -> bwzs/wallpapers
~/.local/share/aurorae              -> bwzs/aurorae
~/.local/share/color-schemes        -> bwzs/colorschemes
~/.spicetify/Themes                 -> bwzs/spicetify/workspace/Themes
~/.config/spicetify/config-xpui.ini -> bwzs/spicetify/config/config-xpui.ini
~/.gtkrc-2.0                        -> bwzs/gtk/.gtkrc-2.0
```

Components that pull from more than one home path keep their source-dir
name inside the folder (`gtk/gtk-3.0`, `gtk/gtk-4.0`), and `spicetify`
uses `workspace/` for `~/.spicetify` and `config/` for `~/.config/spicetify`.

### Components

| Component | Contents |
|---|---|
| `alacritty` | `~/.config/alacritty` |
| `aurorae` | `~/.local/share/aurorae` (window decorations) |
| `colorschemes` | `~/.local/share/color-schemes` |
| `fastfetch` | `~/.config/fastfetch` |
| `fish` | `~/.config/fish` |
| `gtk` | `~/.config/gtk-3.0`, `~/.config/gtk-4.0` (as `gtk-3.0/`, `gtk-4.0/`) and `~/.gtkrc-2.0` |
| `kde` | loose KDE config files in `~/.config` (kdeglobals, kwinrc, …) |
| `kitty` | `~/.config/kitty` |
| `mpv` | `~/.var/app/io.mpv.Mpv/config/mpv` (Flatpak) |
| `nvim` | `~/.config/nvim` |
| `oh-my-posh` | `~/.config/oh-my-posh` |
| `plasma` | plasma runtime config (`~/.config/plasma-*rc`, `~/.config/plasmarc`, `~/.config/plasmashellrc`) + `~/.local/share/plasma` (desktoptheme, look-and-feel, plasmoids, wallpapers) |
| `spicetify` | `~/.spicetify` → `workspace/` (Themes, Extensions, CustomApps); `~/.config/spicetify` → `config/` (Themes, config-xpui.ini) |
| `wallpapers` | `~/.local/share/wallpapers` |

## Syncing

`./backup.sh [theme]` copies the matching `$HOME` paths into the selected
theme folder (via the mapping above), then commits & pushes. `rsync
--delete` keeps the repo mirror exact. Default theme is `bwzs`.

## Tweaks

One-off tweaks live in `tweaks/<name>/`, each documented in
[tweaks/README.md](tweaks/README.md).

## Notes

- `nord/` doesn't exist yet — `./backup.sh nord` creates it on first run.
- Spicetify-generated files (binary, tokens, states) are git-ignored.
- Nothing sensitive is tracked here; KDE session/activity/wallet state is
  deliberately excluded from the sync pairs.

## Merged repositories

Formerly separate repos, merged with their full git history intact
(each source `main` is a second parent of its import commit):

| Folder | Source repo | Contents |
|---|---|---|
| `config-backup/` | Zsweezzy/config-backup | Full `config/`, `home/`, `nix/` backup mirror + `backup.sh` |
| `tokyonight-moon-dotfiles/` | Zsweezzy/tokyonight-moon-dotfiles | Live hyprland/quickshell/rofi mirrors for the tokyonight-moon theme |
| `system/` | Zsweezzy/system | System tuning docs (numbered `*.md`) + `scripts/` |

## For AI agents and contributors

- Config files keep their comments exactly as the app expects them — a `#`
  line in a config is often semantic (a documented key), never strip it.
  Zero-comment files stay zero-comment; `backup.sh` resyncs from `$HOME`
  with `rsync --delete`, so hand edits here are proposals, not truth.
- The sync direction is one-way (`$HOME` → repo). If you change a file here
  on purpose, run `./backup.sh` on the live machine so the mirror and the
  config agree again.