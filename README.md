# ZSW-Dotfiles

Theme configs for Zsweezzy's CachyOS/Hyprland/Plasma setup. Two themes are
live, one is a placeholder:

```
tokyonight/    Tokyo Night Moon (current default)
monochrome/    true grayscale (formerly bwzs)
nord/          placeholder, filled by ./backup.sh nord once the theme exists
```

## Layout

Each theme is split into **component folders** named after the app/system that
owns the config. The component folder **is** the app folder, so applying is a
clean drag-and-drop:

```
~/.config/kitty/kitty.conf          -> tokyonight/kitty/kitty.conf
~/.config/kdeglobals                -> tokyonight/kde/kdeglobals
~/.config/plasma-org.kde…appletsrc  -> tokyonight/plasma/plasma-org.kde…appletsrc
~/.local/share/plasma/desktoptheme  -> tokyonight/plasma/desktoptheme
~/.local/share/wallpapers           -> tokyonight/wallpapers
~/.local/share/aurorae              -> tokyonight/aurorae
~/.local/share/color-schemes        -> tokyonight/colorschemes
~/.spicetify/Themes                 -> tokyonight/spicetify/workspace/Themes
~/.config/spicetify/config-xpui.ini -> tokyonight/spicetify/config/config-xpui.ini
~/.gtkrc-2.0                        -> tokyonight/gtk/.gtkrc-2.0
```

Components that pull from more than one home path keep their source-dir name
inside the folder (`gtk/gtk-3.0`, `gtk/gtk-4.0`), and `spicetify` uses
`workspace/` for `~/.spicetify` and `config/` for `~/.config/spicetify`.

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
| `mpv` | `~/.var/app/io.mpv.Mpv/config/mpv` (Flatpak; tokyonight only) |
| `nvim` | `~/.config/nvim` |
| `oh-my-posh` | `~/.config/oh-my-posh` |
| `plasma` | plasma runtime config (`~/.config/plasma-*rc`, `~/.config/plasmarc`, `~/.config/plasmashellrc`) + `~/.local/share/plasma` (desktoptheme, look-and-feel, plasmoids, wallpapers) |
| `spicetify` | `~/.spicetify` → `workspace/` (Themes, Extensions, CustomApps); `~/.config/spicetify` → `config/` (Themes, config-xpui.ini) |
| `wallpapers` | `~/.local/share/wallpapers` |

### tokyonight/extras

`extras/` is the former `tokyonight-moon-dotfiles` repo, kept for reference:

- `hyprland/.config/hypr` — Hyprland config and scripts (live copies are owned
  by `cachyos-rebuild/home/.config/hypr`)
- `quickshell/.config/quickshell/tokyonight` — snapshot of the old shell; live
  configs are owned by `ZSW-Quickshell`
- `rofi/.config/rofi`, `rofi/.local/share/rofi/themes` — launcher config
- `audio-popup/`, `timer-sound/` — Cargo helpers for the shell

The sync scripts ignore `extras/`; it is a mirror, not a source of truth.

## Syncing

`./backup.sh [theme]` copies the matching `$HOME` paths into the selected
theme folder (via `components.sh`), then commits & pushes. `rsync --delete`
keeps the repo mirror exact. Default theme is `tokyonight`.

`./apply.sh [theme]` is the reverse: it copies one theme folder back into
`$HOME`. Use it on a fresh install. Both scripts read the same mapping from
`components.sh`.

The live palette switcher (`~/.local/bin/theme`) generates `kdeglobals`,
GTK CSS, kitty colours, the Quickshell palette and wallpapers from
`~/.config/themes/<slug>/theme.conf`. Those generated files are what
`backup.sh` captures; if you change a palette, change `theme.conf` first and
re-run `theme set <slug>`.

## System tweaks

Root-level tweaks and one-off desktop overrides moved to
[`Zsweezzy/cachyos-rebuild`](https://github.com/Zsweezzy/cachyos-rebuild)
(`/etc`, GameMode, sysctls, arch-update desktop entry, `reapply-darkmode`).
This repo is themes only.

## Notes

- Spicetify-generated files (binary, tokens, states) are git-ignored.
- Nothing sensitive is tracked here; KDE session/activity/wallet state is
  deliberately excluded from the sync pairs.
- The former `config-backup/`, `system/`, and `tweaks/` trees were merged from
  their own repositories and have since been folded into `cachyos-rebuild`.
  Their history is still in this repo's merge commits.

## Related repos

| Repo | Contents |
|---|---|
| `Zsweezzy/ZSW-Quickshell` | Live Quickshell configs (`Tokyonight lite`, `Tokyonight full`, `theme-picker`) |
| `Zsweezzy/cachyos-rebuild` | Packages, `/etc`, system tweaks and machine-specific setup |

## For AI agents and contributors

See [`AGENTS.md`](AGENTS.md). The short version: config files keep their
comments exactly as the app expects them, and the sync direction is one-way
(`$HOME` → repo) for `backup.sh`.
