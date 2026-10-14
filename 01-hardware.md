# 01 — Hardware

Hostname `C3PO`.

## CPU

- **AMD Ryzen 9 7950X3D** — 16 cores / 32 threads, single socket.
- Base/max: 4.2 GHz base, boost up to **5763 MHz** (CPU max MHz reported 5763.3560).
- **Cache is split across two CCDs** — this matters for pinning:
  - `cpu0-7` and `cpu16-23` share **98304 KiB (96 MiB) L3** — the **3D V-Cache CCD**.
  - `cpu8-15` and `cpu24-31` share **32768 KiB (32 MiB) L3** — the normal CCD.
  - Verified via `/sys/devices/system/cpu/cpuN/cache/index3/shared_cpu_list`.
- L2: 16 MiB total (16 x 1 MiB). L1d/L1i: 512 KiB each (16 instances).
- `amd_pstate` driver: `amd-pstate-epp`, status `active`, `prefcore=enabled`
  (preferred-core ranking exposed = 196).
- Boost: `1` (enabled).

Practical consequence: on this chip the OS/driver generally places latency-sensitive
work on the cache-rich CCD. Do not blind-pin a game to `cpu8-15`; the 32 MB CCD is the
*weaker* one for cache-heavy games.

## GPU

- **dGPU: AMD Radeon RX 7900 XTX** (Navi 31), PCI `03:00.0`, id `1002:744c` (rev c8).
  - Driver stack: **RADV** (Mesa), Mesa version **26.2.4** (Arch `mesa 26.2.4-1`).
  - DRM node: **`card1`** (this is the one games use).
  - `power_dpm_force_performance_level = auto` (driver ramps clocks on demand).
  - Idle clocks observed: sclk floor 176 MHz, top tier 2431 MHz;
    mclk active tier 1249 MHz while the always-on recorder is running (floor 96 MHz).
- **iGPU: AMD Raphael / Radeon 610M** (integrated), PCI `12:00.0`, id `1002:164e` (rev c9),
  DRM node `card0`. Present but not used for games.

## Memory

- **30 GiB** usable RAM (32 GB physically).
- **zram0: 30.2 GiB**, algorithm `zstd`, swap priority 100.
- Plus a disk swap partition (see `05-storage-memory.md`) — total swap ~49 GiB.

## Storage

- `/` and `/home`: **btrfs** on `/dev/nvme0n1p7`, mounted
  `compress=zstd:1,noatime`, subvolume `@`.
- `/home/maxii/games`: **NTFS** on `/dev/sda2` via the in-kernel **ntfs3** driver
  (separate SATA SSD/HDD — see `05-storage-memory.md`).

## Monitors

| ID | Output    | Mode                | Scale | Position |
|----|-----------|---------------------|-------|----------|
| 0  | DP-1      | 3840x2160 @ 144 Hz  | 2     | 1920,0   |
| 1  | DP-2      | 1920x1080 @ 240 Hz  | 1     | 3840,0   |
| 2  | HDMI-A-1  | 1920x1080 @ 100.08 Hz | 1   | 0,0      |

All three report `vrr = false` (VRR is intentionally off — see `06-displays-vrr.md`).

## Peripherals / extras that touch the system

- Xbox-style controllers used for the earlier trigger-rumble work
  (repo `Zsweezzy/linux-xbox-trigger-rumble`).
- OpenDeck (stream deck) and OpenRGB are installed but currently *disabled* in Hyprland
  autostart (OpenRGB autostarts via XDG autostart instead).
