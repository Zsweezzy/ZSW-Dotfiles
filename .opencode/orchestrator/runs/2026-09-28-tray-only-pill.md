# run: tray-only-pill   status: active
request: reduce the apps pill to SNI tray apps only — delete the open-apps group and the `special:tray` placeholder cells, rename `OpenApps.qml` → `Tray.qml`, drop the `SUPER+SHIFT+C` hide-to-tray bind — acceptance: pill shows only SNI items, all apps from all workspaces, no window is left un-restorable, the 9 in-flight user files are byte-identical afterwards

base: main @ 52d7e7f89bf205d4e5d65eb3b6cfc0a390f8b3c4

| id | kind | status | complexity | model | session | worktree/branch | validated_commit | rounds | depends_on |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| unbind-tray-workspace | implementation | pending | normal | default | — | live `~/.config/hypr/hyprland.lua` (outside repo, no worktree) | — | — | — |
| tray-only-pill | implementation | pending | complex | default | — | `task/tray-only-pill` | — | — | — |
| verify-tray-only | verification | pending | normal | default | — | snapshot at integration commit | — | — | unbind-tray-workspace, tray-only-pill |

## Decisions
- 2026-09-28: base is `52d7e7f`, not `4ed3de4` — two later commits touch `.opencode/orchestrator/` only, zero QML. Never `reset --hard` back; merge only. (rejected: rebasing onto the older base)
- 2026-09-28: 9 dirty files are the user's in-flight work, not drift to clean. The run must leave them byte-identical, verified by sha256 against `/tmp/opencode/dirty-baseline.txt`. (rejected: stashing, or `git checkout` to "get clean")
- 2026-09-28: keep the worktree for the quickshell change. (rejected: editing the live checkout — the 9 dirty files are exactly the reason to isolate)
- 2026-09-28: `unbind-tray-workspace` and `tray-only-pill` implement in parallel (disjoint scopes); integration is ordered 1 → 2 so the bind can never be removed before nothing can restore a hidden window.
- 2026-09-28: `unbind-tray-workspace` gets backups instead of a worktree — its target `~/.config/hypr/hyprland.lua` is not in this repo and `~/.config/hypr` is not a git repo (not approved to `git init`).
- 2026-09-28: skip the stale `OpenApps.qml` reference at `Workspaces.qml:43` — that file is mid-edit by the user, and any branch touching it would revert their `radius: height / 2`. Handed to the user as a one-line fix instead.
- 2026-09-28: skip `README.md` — dirty, and 9 of its references go stale (lines 30, 41, 65, 84, 90, 98, 99, 119, 798; line 65 documents exactly the deleted window-event refresh). Report the list, do not edit.
- 2026-09-28: N1 = A. SamRewritten is not an SNI item (only Steam and openRGB are registered with the watcher), so it has no business in a tray pill. Placeholder cells deleted; its window stays parked in `special:tray`.
- 2026-09-28: N2 = fix `iconUrl` with a lowercased retry — `Quickshell.iconPath` is case-sensitive (proved: `samrewritten` resolves, `SamRewritten` returns `""`), one `||`.
- 2026-09-28: N3 = `genericGlyph` U+F0C8 → U+F0AD. U+F0C8 is literally `fa-square` in JetBrains Mono Nerd Font, which is the square the user saw; U+F0AD is `fa-wrench`, what the code comment and the previous ledger both claimed. (rejected: keeping the square as a deliberate "unknown" marker — the code never intended it)
- 2026-09-28: tray cells stay icon-first, glyph as fallback — pre-existing behaviour the user has been living with. Not changed. (not re-litigated)
- 2026-09-28: no model config file at `.opencode/orchestrator.md` or `~/.config/opencode/orchestrator.md` → session default everywhere, no explicit `model` passed.

## Findings & risks
- The square: `iconUrl("org.samrewritten.SamRewritten")` missed on case, then the last-dotted-segment retry produced `SamRewritten` — still wrong case — so it fell through to `genericGlyph` = `fa-square`. Two independent defects, both now fixed. A real icon exists at `/usr/share/icons/hicolor/64x64/apps/samrewritten.png`.
- Deleting `_sniCovers` would break `_coveredTrayWindow` and with it SNI left-click restore. Deleting the `onRawEvent` `Connections` is safe — it only ever called `openAppsPoll.refresh()`. QML resolves calls at runtime, so both failure modes are silent at load.
- The clients `Poll` has no `id`, so "refresh on hover" had nothing to call. Add `id: trayPoll` or the hover path is dead.
- `Image.source` is url-typed: `source === ""` is always false. Judge glyph visibility on `icon.status === Image.Null || icon.status === Image.Error`.
- Only one process may own StatusNotifierWatcher, so a second `quickshell -p` probe sees 0 SNI items. The `Quickshell.iconPath` probe did not import SystemTray and was safe.
- `quickshell log` prints the whole journal, not just since the last reload. Scope every claim to lines after the last `Configuration Loaded` — the `PROBE` lines visible in the journal are historical, from the previous run's since-removed instrumentation.
- Dirty files, never to be touched, stashed, or restored: `ClockFlyout.qml`, `QuadCell.qml`, `README.md`, `TimerCreator.qml`, `TimerPanel.qml`, `TimerState.qml`, `Tokyo.qml`, `TrayMenu.qml`, `Workspaces.qml`.

## Baseline (sha256, first 16 hex)
```
dfb6c27b391d50c6  ClockFlyout.qml      71c347c9da72d889  Tokyo.qml
54855b46b3fabcd0  QuadCell.qml         a23489038276e69e  TrayMenu.qml
3a2983de3237369c  README.md            137e7af7910cf02b  Workspaces.qml
9c7787f4120b5c17  TimerCreator.qml
c69cf3cba68feef0  TimerPanel.qml
ca9d1dca1b03587d  TimerState.qml
```
