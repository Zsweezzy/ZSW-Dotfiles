# orchestrator learnings

## 2026-09-28 — tokyonight quickshell config (first run)
- Repo facts: config at `~/.config/quickshell/tokyonight`, launched `quickshell -c tokyonight` (v0.3.1, Arch), hot-reloads on save. No build system; checks are `bash -n`, running the scripts, and the reload log.
- Verification without qmllint: `quickshell -c tokyonight log` — success is `Reloading configuration...` followed by `Configuration Loaded`; a failed reload keeps the OLD bar running and only pops an overlay, so never trust the screen. Also `opencode debug lsp diagnostics <abs .qml path>`.
- `Quickshell.iconPath(name, true)` (0.3.1) resolves freedesktop theme names and returns "" on a miss; `hasThemeIcon()` is the predicate. Works with no `//@ pragma IconTheme` — the active GTK theme is picked up. A plain `Image { source: ... }` renders the result, SVG included.
- Dead code to be careful with: `TrayIcon.qml` + `scripts/icon-resolve.sh` were retired with the tray merge but left on disk; the `find`-based resolver cost 3.9 s per miss. Prefer the built-in.
- Sub-agents on some providers refuse to run from this host ("free tier can only be used from within OpenCode") — retry with a different agent type.
- 2026-09-28: QML `Image.source` is url-typed, so `source === ""` is ALWAYS false (measured: `source === ""` false, `String(source) === ""` true). Test `icon.status === Image.Null` instead. A url/string compare as a visibility guard silently blanks cells and never throws.
- 2026-09-28: SNI `icon` is not a theme name — Steam sends a full `image://icon/steam_tray_mono?path=...` URL, others send `image://qspixmap/N/M`, openRGB sends an empty `IconName` (quickshell synthesizes a pixmap URL). Pass any `://` string through untouched; `Quickshell.iconPath` cannot resolve them.
- 2026-09-28: a sub-agent that edits a live config and dies (rate limit) leaves instrumentation behind. Always `cp` aside + restore + prove with sha256 against `git show HEAD:file`; check `git status` on the live file FIRST after any sub-agent error.
- 2026-09-28: only one process can own StatusNotifierWatcher, so a second `quickshell -p` probe sees 0 SNI items. Read tray state from the LIVE instance's log (instrument + `quickshell -c tokyonight log`) or from D-Bus directly (`busctl --user introspect :1.NNN /StatusNotifierItem`).
- 2026-09-28: a failed hot-reload leaves the OLD bar on screen, so the screen always looks fine. Only the log distinguishes success.
