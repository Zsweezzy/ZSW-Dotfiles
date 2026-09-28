# run: tray-only-pill   status: done
request: reduce the apps pill to SNI tray apps only — delete the open-apps group and the `special:tray` placeholder cells, rename `OpenApps.qml` → `Tray.qml`, drop the `SUPER+SHIFT+C` hide-to-tray bind — acceptance: pill shows only SNI items, all apps from all workspaces, no window is left un-restorable, the 9 in-flight user files are byte-identical afterwards

base: main @ 52d7e7f89bf205d4e5d65eb3b6cfc0a390f8b3c4
integrated: 62b03a1 (merge of `ebc82b7` into main); `hyprland.lua` sha256 0f53195135970600f2ac294494e6da2d504eec6c110be7d808a60e373ac66fea

| id | kind | status | complexity | model | session | worktree/branch | validated_commit | rounds | depends_on |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| unbind-tray-workspace | implementation | **validated** | normal | default | `ses_f181b9d86ffeWXCrLhmtWtRxBT` | live `~/.config/hypr/hyprland.lua` (outside repo, no worktree) | `sha256 0f531951…` | 0 | — |
| tray-only-pill | implementation | **validated + integrated** | complex | default | `ses_f181b34c1ffezds5ix7FRlrjzF` | worktree removed, branch deleted | `ebc82b7` → merged as `62b03a1` | 2 | — |
| verify-tray-only | verification | **done inline** | normal | default | orchestrator | live config at `62b03a1` | n/a | — | both |

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
- 2026-09-28: two premises in the `unbind-tray-workspace` brief were wrong and the implementer corrected them rather than complying — there is no `SUPER+CTRL+SHIFT+C` bind in `hyprland.lua`, and there is no `special:tray` explanatory block comment (both mentions were inside the deleted bind). Verified against the `bak4`–`bak8` chain. It added no replacement comment, which is correct: a comment naming a workspace that appears nowhere in the config would create the misleading reference the brief forbade.
- 2026-09-28: `unbind-tray-workspace` gate passed on round 0 — reviewer found no blocking issues and its independent re-derivation confirmed all three load-bearing claims. Because the target is not in a git repo, its validated identity is the file's sha256 rather than a commit.
- 2026-09-28: `tray-only-pill` round 0 review found no blocking issues but three real non-blocking findings: the rewritten header and two in-file comments document glyph-first precedence while the code is icon-first (a future editor trusting the header would "fix" the `visible` binding and regress the native-icon fallback), and the `iconSize` comment over-claims a load-time-resize protection a constant cannot provide. Sent to rework round 1. **Rejected** the reviewer's third finding (delete the orphan `import Quickshell.Hyprland` at `Bar.qml:14`): its stated reason — that the removed open-apps group was the last consumer — is false, since `git show 52d7e7f:Bar.qml | grep Hyprland` returns only that import line, so it was already an orphan before this run. Pre-existing, unrelated, and removing it would enlarge the diff.
- 2026-09-28: two implementer flags were correct pushback on the brief — the repo uses 4 spaces, not tabs, in all 30 QML files; and `opencode debug lsp diagnostics` does not exist in this opencode version (`debug` has only agents/config/paths), so the `learnings.md` entry recording it is stale. It also correctly declined to run `quickshell -p` against the worktree, which would contend for `StatusNotifierWatcher` and strip tray icons from the live bar.

## Findings & risks
- 2026-09-28: the pill is verified live, not just in code — a `grim` capture of DP-1 shows the tray pill holding exactly 2 cells, both icons (Steam, openRGB), with zero `Tokyo.pink` pixels (no open-app glyphs), no `fa-square` cell, and no separator gap. Reload log's last line is `Configuration Loaded` with nothing after it. 12/12 idle samples spawned no `hyprctl`/`jq`, and `Poll.qml:58` gates the timer on `active: false`.
- 2026-09-28: **not verified** — hover tooltip, left-click restore and right-click menu. All three need the user's cursor on a live bar. The restore path is additionally unexercisable right now: the only window in `special:tray` is SamRewritten, which has no SNI item, so no tray cell maps to it.
- 2026-09-28: after the bind removal the `special:tray` restore path in `Tray.qml` has **no producer left** — nothing in the config now parks a window there. It is dormant, not dead: `hyprctl dispatch togglespecialworkspace tray` still restores by hand. This is the accepted consequence of `unbind-tray-workspace` + tray-only, decided by the user under N1, not a defect of either delivery.
- 2026-09-28: `README.md:85-95` still documents the merged open-apps pill and the `SUPER + SHIFT + C` bind. The file is dirty and out of scope; the stale lines are handed to the user by hand.
- 2026-09-28: **4 of the 9 in-flight files were edited by the user mid-run** — `ClockFlyout.qml`, `QuadCell.qml`, `README.md`, `Tokyo.qml`, mtimes 14:08–14:13. They are NOT byte-identical to the run-start baseline. The merge provably did not touch them (`git diff 227cdbb 62b03a1` on those paths is empty), so the change is the user's, not ours. Consequence checked: all 8 `Tokyo.*` properties `Tray.qml` reads still exist in the edited `Tokyo.qml`. The run-start sha256 baseline stays in `/tmp/opencode/dirty-baseline.txt` and must not be cited as proof of preservation for these four.
- 2026-09-28: no `qmlls`/`qmlformat`, quickshell has no validate mode, and `opencode debug lsp diagnostics` does not exist in this opencode version — structural review plus manual read-through is the only available check for QML here. The prior `learnings.md` entry asserting that command works has been corrected.
- 2026-09-28: simplification pass returned **zero edits** — nothing worth changing. It surfaced one real leftover: `Tray.qml:108-109`'s `title` and `pid` in the poll's map literal are now unread, since the deleted placeholder cell was their last consumer. Left in place deliberately — the change sits directly on the fragile restore mechanism, and a window title is the obvious payload if that is ever extended.
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
