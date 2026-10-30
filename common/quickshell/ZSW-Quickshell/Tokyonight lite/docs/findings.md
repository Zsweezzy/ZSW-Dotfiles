# Findings — APIs and traps met while building the roadmap slices

Environment: Quickshell 0.3.2 (Arch), Qt 6, Hyprland.

## Lock

- `Quickshell.Wayland.WlSessionLock` is a `Reloadable` with `locked`,
  read-only `secure`, and a default `surface: Component`. Set `locked = true`
  to lock; the compositor asks for a surface per output.
- `WlSessionLockSurface` is the per-output item; it is created by the lock.
- `Quickshell.Services.Pam.PamContext`: `start()` returns bool, `respond(text)`,
  `abort()`, `active`, `message`, `responseRequired`, `responseVisible`, and
  `onCompleted(result)` where `PamResult.Success` unlocks.
- PAM service name: `login` works on this machine (`/etc/pam.d/login` includes
  `system-local-login`); `hyprlock` exists too but is a copy of the same chain.
  No `pam_fprintd` line is configured, so fingerprint is not advertised.
- Never trigger the real lock while developing: a failed surface leaves the
  session locked with no way in. Verify the reload only.

## Notifications

- `NotificationServer` survives reload with `keepOnReload`.
- Grouping has to happen in the panel, not the daemon: the history is flat and
  already persisted; a group is a view of it.
- Per-app mute belongs in the store so toasts and history agree.

## OSD

- `Pipewire.defaultAudioSink.audio.volume` is 0..1; `muted` is separate.
- Brightness has no Quickshell service on this box: `brightnessctl` is the
  source (`brightnessctl -m` prints `device,class,current,percent,max`).
- Microphone mute is `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`, read back
  with `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` (`[MUTED]` suffix).

## Settings

- `Quickshell.Io.FileView` + `JsonAdapter` persists declared adapter
  properties; `writeAdapter()` writes. The adapter is FileView's default
  property.
- Keep the settings file outside the config tree so a save is not a git diff:
  `~/.config/quickshell/tokyonight-settings.json`.

## Idle

- `IdleMonitor` lives in the private module `Quickshell.Wayland._IdleNotify`
  (`enabled`, `timeout`, `respectInhibitors`, `isIdle`). It only reports idle;
  the reaction is ours.
- `hyprctl dispatch dpms off` turns the panel off; any input wakes it.
- Do not lock on idle while a fullscreen window is playing video: check
  `Hyprland` clients for fullscreen >= 2 first (same probe the bar uses).

## Battery

- `Quickshell.Services.UPower.UPower.displayDevice` is the aggregate;
  `isLaptopBattery`, `percentage`, `state`, `timeToEmpty`, `onBattery`.
  A desktop reports a device with `isPresent: false` — hide then.

## Media

- `Mpris.players.values` is the player list; `position` is writable for seek.
- The capsule's media pill follows one player. A picker needs the chosen
  player to survive the panel closing, so the selection lives in the module.

## Performance

- Poll intervals are per-file today (`Sys`, `Updates`, `NotificationStore`).
  One `Perf.qml` singleton keeps them from drifting.
- A committed baseline matters more than a micro-optimisation: record the
  process RSS and the idle CPU after a reload.

## IPC and the `island` wrapper

- `qs -c "ZSW-Quickshell/Tokyonight lite" ipc call island <fn> [args]` is the
  whole surface; every `IpcHandler` function here returns void, so anything
  that needs an answer reads the state file instead (`island status`).
- `IpcHandler` argument types come from the QML signature: `dnd(on: bool)`
  takes `true`/`false`, not `on`/`off` — the wrapper does that mapping.
- Volume and brightness stay out of the shell: the OSD follows PipeWire
  directly, so `wpctl` needs no IPC at all.

## Theme switching

- `theme set <slug>` regenerates `ThemeColors.qml`; the shell reloads on
  content change only. Same theme = identical bytes = no reload, which is
  correct and looks like a dead watcher if you only compare mtimes.

## Reload discipline

- `scripts/check-reload.sh` after every QML save. Exit 0 = loaded.
- Never grep the journal; it replays stale loads.
