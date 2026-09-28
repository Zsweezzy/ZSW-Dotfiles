# run: tray-native-icon-fallback   status: done
request: tray cells fall back to the app's own icon when no nerd-font glyph is mapped (openRGB should use its native icon) — acceptance: mapped glyph wins, else the app's real icon, else the generic wrench; all three cell kinds in OpenApps.qml; no per-cell process; live bar reloads clean
base: main @ 9f8b60c (config as-is, `git init` + baseline commit)

| id | kind | status | complexity | model | session | worktree/branch | validated_commit | rounds | depends_on |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tray-icon-fallback | implementation | validated | normal | session default | ses_f1862f1afffe6L14zqXgkJYZwx | /tmp/opencode/wt-tray-icons @ task/tray-icon-fallback | ef1162c | 3 | — |
| verify-tray-icons | verification | validated | normal | session default | ses_f184add39ffe5gDtQgeTn0anNn + ses_f18443aa7ffevgnco2wUnA8R9x | live config (instrumented, then restored) | — | 0 | tray-icon-fallback |

Merged to main: e7575c3 -> d1f28af -> 83a0874 -> ef1162c. Net -10 lines for the feature (146 ins / 156 del at e7575c3).

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

## Round log
- Round 1 review: 2 blocking (URL-string test for load failure; unchecked `file://` branch) + 5 non-blocking. All fixed.
- Between rounds, the LIVE log caught what review missed: Steam's SNI `icon` is a whole `image://icon/steam_tray_mono?path=...` URL, so the path branch wrapped a URL in `file://` -> `Cannot open` on every reload. d1f28af.
- Round 2 review: no blocking, 2 comment nits, fixed.
- Independent verification pass on the merged tree returned FAIL: priority was icon-first in 2 of 3 delegates. **Superseded by a user decision — the user chose to keep both cells (SNI + placeholder) rather than dedupe, so the inverted priority is intended, not a defect.** `_sniCovers` deliberately left alone.
- Final live measurement found the real blocker: `visible: icon.source === "" || ...` is dead code because `Image.source` is url-typed (measured `source === ""` false, `String(source) === ""` true). 4 cells painted nothing. ef1162c fixes it via `icon.status === Image.Null || icon.status === Image.Error`; re-measured live, all 4 now paint their glyph.

## Verification evidence (final, measured on the live bar)
- openRGB SNI cell: `icon=image://qspixmap/63/1` (SNI `IconName` is empty, so quickshell generates a pixmap URL), status=Ready, painted 14x14, glyph hidden.
- openRGB `special:tray` placeholder: `icon=image://icon/org.openrgb.OpenRGB`, Ready, 14x14, glyph hidden.
- open-app firefox U+F269, kitty U+F120, steam U+F1B6, SamRewritten U+F0C8 — all painted after ef1162c.
- 0 `Cannot open` / ERROR after the last `Configuration Loaded`.

## Outstanding (not defects, user's call)
- openRGB shows two cells (SNI + tray'd window) by the user's explicit choice. `_sniCovers` cannot match SNI id `openrgb` to class `org.openrgb.OpenRGB`; a one-line change to `_sniCovers` (compare the class's last reverse-DNS segment too) would collapse them for every app, incl. Steam which already dedupes.
- `scripts/openapps-focus.sh` still on disk, referenced only by its own header and a README line calling it retired. Pre-existing.
