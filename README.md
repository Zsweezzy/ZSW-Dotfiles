# system

Snapshot + change-log of Maxii's Linux gaming desktop (hostname `C3PO`), written so an
AI agent can read **only the slice it needs** instead of the whole thing.

Last updated: 2026-10-14.

## How to use this repo

Pick the one file that matches your question. Each file is self-contained and states
what was *measured* vs what was *changed*.

| If you need to know about...                | Read                |
|---------------------------------------------|---------------------|
| What hardware is in this box                | `01-hardware.md`    |
| Bootloader, kernel, kernel cmdline, boot    | `02-os-boot-kernel.md` |
| CPU, X3D cache layout, governor, scheduler  | `03-cpu-scheduler-power.md` |
| GPU, Mesa/RADV, shader cache, MangoHud      | `04-gpu-graphics.md` |
| Disks, btrfs/NTFS, zram, swap, writeback    | `05-storage-memory.md` |
| Monitors, refresh rates, VRR (tried + reverted) | `06-displays-vrr.md` |
| Hyprland config, animations, autostart      | `07-hyprland-desktop.md` |
| Steam/Proton env vars — which ones exist    | `08-steam-proton-flags.md` |
| The exact launch options now on the games   | `09-launch-options-applied.md` |
| Idle CPU/GPU/memory costs, services audit   | `10-idle-costs-services.md` |
| The root/elevated script (user must run it) | `11-root-actions.md` |
| What was measured, what was inconclusive    | `12-measurements.md` |
| Everything changed on 2026-10-14 + backups  | `13-changelog-2026-10-14.md` |

Machine-readable / repeatable bits live in `scripts/`.

## Quick facts

| Item        | Value |
|-------------|-------|
| OS          | CachyOS (rolling), systemd 262 |
| Kernel      | `7.2.10-1-cachyos` (PREEMPT_DYNAMIC) |
| CPU         | AMD Ryzen 9 7950X3D (16c/32t, one 96 MB 3D-V-Cache CCD) |
| GPU         | AMD Radeon RX 7900 XTX (Navi 31), RADV, Mesa 26.2.4 |
| iGPU        | AMD Raphael / Radeon 610M (unused for games) |
| RAM         | 30 GiB + 30.2 GiB zram (zstd) + 19.5 GiB disk swap |
| Root disk   | btrfs `/dev/nvme0n1p7` (compress=zstd:1, noatime) |
| Games disk  | NTFS `/dev/sda2` -> `/home/maxii/games` (ntfs3) |
| Bootloader  | GRUB |
| Desktop     | Hyprland 0.56.2 (Lua config) + quickshell bar |
| Steam       | 79 installed entries, 60 "games" after filtering |
| Governor    | amd-pstate-epp, `performance` / EPP `performance` |
| Sched       | EEVDF (scx_loader running but **no** BPF scheduler attached) |

## The one-line summary of what was done on 2026-10-14

1. **VRR reverted** to the exact pre-edit state (VRR off on all three monitors).
2. **Animations made snappy** (durations cut ~45%, borderangle frozen to static).
3. **Uniform Proton flags applied to 56 Steam games** (3 anti-cheat games excluded).
4. A **root script** was prepared for the changes that need sudo
   (see `11-root-actions.md`) — it has not been run.

Nothing in this repo has been applied at the root level. Everything applied so far is
user-level and reversible; every backup path is listed in `13-changelog-2026-10-14.md`.

## Privacy

Private repo. No credentials, tokens, or account secrets are stored here.
