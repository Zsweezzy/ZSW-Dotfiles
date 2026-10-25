# 10 — Idle costs, services audit, "minimal system" findings

## The honest headline

This machine is **already lean and already tuned**:

- **0 orphan packages** (`pacman -Qdtq` empty).
- **0 failed systemd units**.
- CPU governor/EPP already `performance`; `nowatchdog` already in the cmdline;
  `split_lock_mitigate` already 0; `max_map_count` already raised; writeback already
  bounded; zram already configured and preferred.
- 320 explicit packages, 1628 total.

So the "strip everything" interpretation of *minimal* has almost nothing to gain at the
package level. The real idle cost on this machine is **one optional feature the user
actively uses**, described below, not cruft.

## Top idle costs, measured

### 1. The game-clip recorder (biggest single cost) — LEFT RUNNING ON PURPOSE

- `vice.service` is a **user** service (`/usr/lib/systemd/user/vice.service`,
  `ExecStart=/usr/bin/vice start --no-open-ui`).
- It drives `gpu-screen-recorder` (pid observed 2182):
  `gpu-screen-recorder -w DP-1 -f 60 -r 60 -c mp4 ... -o /home/maxii/Videos/Vice`
  plus `gsr-kms-server` (pid 2191, `/dev/dri/card1`).
- Measured cost while merely watching YouTube:
  - `gpu-screen-recorder` ~**170 MB RSS**, ~**5% CPU cumulative**.
  - GPU **11% busy**, memory clock held at the **1249 MHz** tier instead of its 96 MHz
    floor.
  - The output directory `/home/maxii/Videos/Vice` has content -> the feature is in use.
- **This is a continuous capture / instant-replay feature the user wants.** It is the
  single largest idle cost on the box, but disabling it removes a feature. It was
  therefore **left enabled and documented** rather than silently turned off.

  **One-line toggle if you ever want it off:**
  ```bash
  # RUN THIS YOURSELF (user service, no sudo needed)
  systemctl --user disable --now vice.service     # off
  systemctl --user enable  --now vice.service     # back on
  ```

### 2. VPN daemons (two of them)

| Service | RSS | Notes |
|---------|-----|-------|
| `nordvpnd.service` | ~114 MB | plus `nordvpn-gui` ~248 MB in the session |
| `tailscaled.service` | ~45 MB | second VPN stack, running concurrently |

Two VPN daemons running at once is redundant *if* they are never both needed at the same
time. Candidate for on-demand start. **Not changed** — VPN availability is a user policy
decision.

### 3. The custom bar

- `quickshell` (tokyonight bar) ~**107 MB** RSS. Largest desktop-owned process.
  Not cruft; it is the status bar. Change only if a lighter bar is wanted.

### 4. Auto-tuner

- `bpftune.service` ~7.8 MB, actively rewriting network sysctls at runtime. See
  `03-cpu-scheduler-power.md`. If you want your own sysctls to stick, disable it.

### 5. Idle-but-enabled oddity

- `scx_loader.service` (~2.9 MB) is active and enabled but **no scheduler is attached**
  (see `03`). It is effectively idle.
- `lactd.service` reported a MainPID but ~4 KB RSS (GPU control daemon, mostly idle).
- `plasmalogin.service` ~11.7 MB — the display manager (login screen) still resident
  after login; normal for a DM, kept.

## Full enabled system services (exact list)

```
avahi-daemon.service
bluetooth.service
bpftune.service
coolercontrold.service
cups.service
dmemcg-booster-system.service
getty@.service
lactd.service
lm_sensors.service
NetworkManager-dispatcher.service
NetworkManager-wait-online.service
NetworkManager.service
nordvpnd.service
plasmalogin.service
scx_loader.service
systemd-resolved.service
systemd-timesyncd.service
tailscaled.service
ufw.service
```

### Two of these are actively used — do NOT remove them

| Service | Why it must stay |
|---------|------------------|
| `cups.service` | A real printer is configured: **HP DeskJet 4200, idle**. |
| `avahi-daemon.service` | mDNS discovery. **`kdeconnect 26.08.2` is installed** and depends on it for device discovery. |

### Other services and their verdicts

| Service | RSS | Verdict |
|---------|-----|---------|
| `coolercontrold` | ~30 MB | fan control — **keep** (thermal safety) |
| `lm_sensors` | — | feeds coolercontrol — **keep** |
| `bluetooth` | ~7 MB | keep |
| `NetworkManager` (+dispatcher) | ~22 MB | keep |
| `NetworkManager-wait-online` | — | **disable** — pure boot-time delay on a desktop (in the root script) |
| `ufw` | — | firewall — keep |
| `systemd-resolved`, `systemd-timesyncd` | ~13 MB | keep |
| `dmemcg-booster-system` | ~3 MB | CachyOS memory-cgroup booster — keep (CachyOS default) |
| `power-profiles-daemon` | ~8 MB | running via D-Bus, profile `performance`; not enabled. Harmless. |

## Session-level user services seen running

`gamemoded` (~4 MB), `mako` (~22 MB), `pipewire` (~39 MB), `hyprpolkitagent`,
`dconf`, `gvfs-*`, `xdg-desktop-portal*`, `gnome-keyring-daemon`, `vice` (~30 MB),
plus the cliphist `wl-paste --watch` pair.

None of these are worth removing; they are the desktop's plumbing.

## XDG autostart entries (user session)

`apollo.desktop`, `opendeck.desktop`, `OpenRGB.desktop`,
`org.kde.kdeconnect.daemon.desktop`.

Note the inconsistency: Hyprland's `hyprland.start` *comments out* OpenRGB/OpenDeck
(expecting them to autostart via XDG), while XDG autostart still launches them. That is
intentional, not a bug — just recorded so an AI does not "fix" it twice.

## Bottom line for "minimal system"

| Interpretation | Finding |
|----------------|---------|
| Fewest files / no new packages / reversible | Already true; changes made are one Lua file + one VDF. |
| Reduce idle CPU/GPU wakeups | The dominant cost is the intentionally-running clip recorder; everything else is small. |
| Leanest OS/session | Already 0 orphans / 0 failed units; only `NetworkManager-wait-online` is a clear, safe trim. |

No packages were removed and no service was disabled in this pass. The only *recommended*
service change (`NetworkManager-wait-online`) lives in the root script
(`11-root-actions.md`) because it needs sudo.
