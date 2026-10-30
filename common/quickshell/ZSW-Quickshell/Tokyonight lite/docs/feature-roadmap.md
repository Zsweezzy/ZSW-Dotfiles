# Feature roadmap

Slices taken from the cross-repo shell feature catalogue (Ryoku / Serpantinum /
Noctalia / Caelestia). Ideas only: Ryoku and Caelestia are GPL-3.0, Serpantinum
AGPL-3.0, Noctalia MIT. No copyleft source was copied.

| § | Feature | Slice landed here | Files |
|---|---|---|---|
| 6 | Lock screen | Quickshell `WlSessionLock` surface with PAM, clock, media, battery, unread count, IPC | `Lock.qml`, `LockSurface.qml`, `shell.qml` |
| 7 | Notifications | Group by app, per-app mute, persisted DND | `NotificationStore.qml`, `NotificationsPanel.qml` |
| 8 | OSD & HUD | Volume / brightness / mic OSD with auto-hide and IPC | `Osd.qml`, `shell.qml` |
| 11 | Theming | Runtime palette switch through the existing `theme` tool | `shell.qml`, `scripts/island` |
| 12 | Settings app | Persisted preferences + a Settings flyout in the control centre | `Settings.qml`, `SettingsPanel.qml`, `QuickPanel.qml` |
| 14 | CLI & IPC | One `island` wrapper over the IPC surface | `shell.qml`, `scripts/island` |
| 15 | Services & daemons | Idle daemon: lock and DPMS on `IdleMonitor` | `Idle.qml`, `shell.qml` |
| 18 | Media | Player picker in the media panel, capsule follows it | `Media.qml`, `MediaPanel.qml` |
| 19 | System integration | UPower battery pill, hidden on desktops | `Battery.qml`, `Island.qml` |
| 21 | Performance | One `Perf.qml` policy for poll intervals (one switch, `Settings.lowPower`) | `Perf.qml`, `Sys.qml`, `Updates.qml`, `NotificationStore.qml`, `Bar.qml` |

Deliberately skipped (named, not built): notification inhibitors and scripts,
inline replies, per-monitor lock surfaces with different widgets, video lock
wallpaper, fingerprint/Howdy unlock, compiled QML cache.
