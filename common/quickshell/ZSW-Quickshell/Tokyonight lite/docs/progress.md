# Progress

Live log of the roadmap slices. Each entry: what changed, how it was verified.

## 2026-10-30 — start

- Read `shell.qml`, `Island.qml`, `Bar.qml`, `Panel.qml`, `NotificationStore`,
  `NotificationsPanel`, `Toast`, `Media`, `MediaPanel`, `Audio`, `Quick`,
  `Tokyo.qml`, `DESIGN.md`.
- Confirmed Quickshell 0.3.2 exposes `WlSessionLock`, `PamContext`,
  `IdleMonitor`, `UPower`, `FileView`/`JsonAdapter`.
- Existing lock: `hyprlock` via `Super+L` in `~/.config/hypr/hyprland.lua`
  (separate repo — not touched).

## 2026-10-30 — all nine slices landed

| Slice | What shipped | Verified by |
|---|---|---|
| 12 Settings | `Settings.qml` (JSON in `~/.config/quickshell/tokyonight-settings.json`), `SettingsPanel.qml` flyout in the control centre | toggle writes the file; reload clean |
| 6 Lock | `Lock.qml` + `LockSurface.qml` on `WlSessionLock`, PAM, clock/media/battery/unread, IPC `lock`/`unlock` | IPC `lock` maps the surface, password unlocks |
| 7 Notifications | grouping by app, per-app mute, DND — all persisted in `Settings` | reload clean, DND survives restart |
| 8 OSD | `Osd.qml` bottom-centre strip, auto-hide, follows the PipeWire sink, `IPC osd brightness\|mic` | IPC shows the strip; volume shows itself |
| 15 Idle | `Idle.qml`: two `IdleMonitor`s (lock, DPMS) reading the Settings thresholds | reload clean; thresholds 0 disable |
| 19 Battery | `Battery.qml` pill from `UPower.displayDevice`, removed on desktops | hidden on this desktop (`isPresent: false`) |
| 18 Media | player picker in `MediaPanel`; the pick lives on the module so it outlives the panel | reload clean with two players |
| 21 Perf | `Perf.qml` (`ms()` scale, `Settings.lowPower` doubles every poll) applied to `Sys`, `Updates`, `NotificationStore`, `Bar` | reload clean |
| 14/11 IPC & CLI | `scripts/island` over the IPC surface; `dnd` and `theme` added to `IpcHandler` | `island status`, `island dnd on/off`, `island theme` |

Verification: `scripts/check-reload.sh` exit 0 after every edit, and once more
after the whole set.

Baseline (`scripts/perf-baseline.sh`, after a reload, idle):

    baseline pid=1567046 rss=654MB cpu=157.08s

654 MB RSS is the number to watch; accumulate CPU only moves while something
polls, so compare `CPU time` across a fixed wall-clock window, not across days.

### Theme switch, note

`theme set <slug>` rewrites `ThemeColors.qml`; Quickshell reloads on content
change, not on mtime. Switching to the *same* theme rewrites identical content
and therefore correctly does not reload. A real switch does — verified by
touching the file's content (comment probe) and by regenerating it.

## Deliberately not built

Named in `feature-roadmap.md`: notification inhibitors and scripts, inline
replies, per-monitor lock surfaces with different widgets, video lock
wallpaper, fingerprint/Howdy unlock, compiled QML cache.

Idle locking leans on `respectInhibitors`, which is what mpv and games take.
It does not additionally scan Hyprland clients for fullscreen; that probe is
the fallback if an app that should inhibit turns out not to.
