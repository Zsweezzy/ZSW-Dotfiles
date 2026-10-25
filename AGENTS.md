# AGENTS.md — ZSW-Dotfiles

Theme configs for one CachyOS desktop. Read this before touching files.

## Layout

- `tokyonight/`, `monochrome/`, `nord/` — one folder per theme.
- Inside a theme, component folders map 1:1 to live app directories. The
  mapping is `components.sh`, used by `backup.sh` and `apply.sh`.
- `tokyonight/extras/` is an archived mirror (Hyprland, rofi, old Quickshell,
  Rust helpers). Nothing applies it; do not treat it as live config.
- `nord/` is a placeholder until a Nord palette exists.

## Sync direction

- `./backup.sh [theme]` — live `$HOME` → repo (default `tokyonight`), then
  `git add -A && git commit && git push`. It uses `rsync --delete`, so hand
  edits in the repo are overwritten on the next run.
- `./apply.sh [theme]` — repo → live `$HOME` (fresh-install restore).
- If you intentionally change a repo file, run `./backup.sh` on the live
  machine so the mirror and the config agree again.

## Ownership

Do not duplicate these here; they live in their own repos or systems:

| Path | Owner |
|---|---|
| `~/.config/themes`, `~/.local/bin/theme` | `ZSW-CachyOSRebuild` |
| `~/.config/hypr` | `ZSW-CachyOSRebuild/home` |
| `~/.config/quickshell` | `Zsweezzy/ZSW-Quickshell` |
| `~/.config/opencode` | `Zsweezzy/ZSW-OpencodeBackup` |
| `/etc`, root tweaks, GameMode, sysctls | `Zsweezzy/ZSW-CachyOSRebuild` |

## Rules

- Config files keep their comments exactly as the app expects them. A `#` line
  is often a documented key — never strip it. Zero-comment files stay
  zero-comment.
- Never commit generated Spicetify binaries/tokens/states; `.gitignore` covers
  them.
- Nothing sensitive belongs here.
- Run `bash -n apply.sh backup.sh components.sh` after editing scripts.

## Verify

```bash
bash -n apply.sh backup.sh components.sh
git status --short
```
