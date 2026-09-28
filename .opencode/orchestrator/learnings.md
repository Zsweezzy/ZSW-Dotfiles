# orchestrator learnings

## 2026-09-28 — tokyonight quickshell config (first run)
- Repo facts: config at `~/.config/quickshell/tokyonight`, launched `quickshell -c tokyonight` (v0.3.1, Arch), hot-reloads on save. No build system; checks are `bash -n`, running the scripts, and the reload log.
- Verification without qmllint: `quickshell -c tokyonight log` — success is `Reloading configuration...` followed by `Configuration Loaded`; a failed reload keeps the OLD bar running and only pops an overlay, so never trust the screen. Also `opencode debug lsp diagnostics <abs .qml path>`.
- `Quickshell.iconPath(name, true)` (0.3.1) resolves freedesktop theme names and returns "" on a miss; `hasThemeIcon()` is the predicate. Works with no `//@ pragma IconTheme` — the active GTK theme is picked up. A plain `Image { source: ... }` renders the result, SVG included.
- Dead code to be careful with: `TrayIcon.qml` + `scripts/icon-resolve.sh` were retired with the tray merge but left on disk; the `find`-based resolver cost 3.9 s per miss. Prefer the built-in.
- Sub-agents on some providers refuse to run from this host ("free tier can only be used from within OpenCode") — retry with a different agent type.
