# run: tray-native-icon-fallback   status: active
request: tray cells fall back to the app's own icon when no nerd-font glyph is mapped (openRGB should use its native icon) — acceptance: mapped glyph wins, else the app's real icon, else the generic wrench; all three cell kinds in OpenApps.qml; no per-cell process; live bar reloads clean
base: main @ 9f8b60c (config as-is, `git init` + baseline commit)

| id | kind | status | complexity | model | session | worktree/branch | validated_commit | rounds | depends_on |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tray-icon-fallback | implementation | pending | normal | session default | — | /tmp/opencode/wt-tray-icons @ task/tray-icon-fallback | — | 0 | — |
| verify-tray-icons | verification | pending | normal | session default | — | base checkout (live config) | — | 0 | tray-icon-fallback |

## Decisions
- 2026-09-28: git init the config dir (user-approved) — no VCS existed; a broken QML edit kills the whole bar. base 9f8b60c.
- 2026-09-28: rule = glyph-first, native icon as fallback (user choice). Mapped font glyph wins; unmapped -> app's own icon; neither -> generic \uf0c8. (Rejected: native-first — user picked glyph-first when shown both.)
- 2026-09-28: scope = tray cells AND open-app cells (user choice) — all three delegates in OpenApps.qml.
- 2026-09-28: use `Quickshell.iconPath(name, true)` instead of reviving TrayIcon.qml + scripts/icon-resolve.sh. Verified live: resolves openrgb/kitty/firefox/steam -> `image://icon/<name>`, returns "" for SamRewritten; plain Image renders the YAMIS SVGs (status=Ready). Removes a per-cell `sh -c` + 3.9 s `find` on misses and the Process.command-while-running wrong-icon bug. TrayIcon.qml and icon-resolve.sh are deleted as dead code (nothing else references them).
- 2026-09-28: delete the openrgb entry in glyphFor() — openRGB runs --startminimized with no window, so it can only reach the bar as an SNI cell; under glyph-first its mapped \uf1de could never lose, so the user's named example would be undeliverable without this. Resolves the contradiction between the rule they chose and the example they gave. One line restores the glyph.
- 2026-09-28: no `//@ pragma IconTheme` — verified unnecessary, iconPath already resolves through the active YAMIS theme.
- 2026-09-28: verify on the live instance (`quickshell -c tokyonight` hot-reloads). No qmllint/qmlformat installed; use `opencode debug lsp diagnostics` + the reload log.

## Findings & risks
- Qt6 SVG image plugin present (/usr/lib/qt6/plugins/imageformats/libqsvg.so); active theme YAMIS is 100% .svg, so every resolved icon is an SVG.
- A failed hot-reload does NOT kill the bar: quickshell keeps the old config and shows a ReloadPopup. The screen lies — only `quickshell -c tokyonight log` distinguishes success (Reloading -> Configuration Loaded) from failure.
- openapps.sh's JSON has exactly one consumer (OpenApps.qml). Empty middle field survives `jq split("\t")` (verified).
- Tray icons are artwork and cannot be tinted, so the pink/muted color split now applies to glyph cells only. Accepted tradeoff.
- `SamRewritten` (a real special:tray client) has no theme icon -> exercises the generic-glyph path in production.
