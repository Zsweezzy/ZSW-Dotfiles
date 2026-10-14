# 05 — Storage and memory

## Block devices (measured)

| Device | Size | FS | Mount | Notes |
|--------|------|----|-------|-------|
| `/dev/nvme0n1` | 1.8 T | | | main NVMe |
| `├─nvme0n1p1` | 200 M | vfat | | EFI/system partition (small) |
| `├─nvme0n1p2` | 16 M | | | MSR |
| `├─nvme0n1p3` | 1000 G | ntfs | (not mounted) | almost certainly a **Windows** install |
| `├─nvme0n1p4` | 846 M | ntfs | (not mounted) | Windows recovery |
| `├─nvme0n1p5` | 1.3 G | vfat | `/boot/efi` | EFI System Partition |
| `├─nvme0n1p6` | 19.5 G | swap | `[SWAP]` | **disk swap**, prio -1 |
| `├─nvme0n1p7` | 179.9 G* | btrfs | `/`, `/home`, `/srv`, ... | Linux root (see below) |
| `└─nvme0n1p8` | 661.2 G | btrfs | (not mounted) | second btrfs partition, currently unused |
| `/dev/sda` | 3.6 T | | | SATA SSD |
| `└─sda2` | 3.6 T | ntfs | `/home/maxii/games` | games library |
| `zram0` | 30.2 G | swap | `[SWAP]` | compressed RAM swap, prio 100 |

\* `lsblk` reports `179.9G` for p7 while `df` reports `842G` for `/` — the partition holds
multiple btrfs subvolumes and the sizes are reported inconsistently by the tooling; the
authoritative free-space number is the `df` one below.

## Root filesystem (btrfs)

`/dev/nvme0n1p7`, one btrfs filesystem with subvolumes:

- `@` -> `/`, `@home` -> `/home`, `@root` -> `/root`, `@srv` -> `/srv`,
  `@cache` -> `/var/cache`, `@log` -> `/var/log`, `@tmp` -> `/var/tmp`.
- Mount options (all): `rw,noatime,compress=zstd:1,ssd,discard=async,space_cache=v2`.
- `noatime` is good (avoids write-on-read); `compress=zstd:1` is a light CPU cost for
  good space savings; `discard=async` is the sane SSD TRIM mode.

Free space: **842 G total, 407 G used, 434 G free (49%)**.

## Games library (NTFS)

- `/dev/sda2` -> `/home/maxii/games`, fs type **`ntfs3`** (in-kernel NTFS driver).
- Options: `rw,relatime,uid=1000,gid=1000,dmask=0000,fmask=0111,acl,iocharset=utf8,prealloc`.
- Size 3.7 T, 3.3 T used, **444 G free (89% full)**.
- Steam libraries:
  - `/home/maxii/.local/share/Steam` (on btrfs)
  - `/home/maxii/games/SteamLibrary` (on this NTFS volume)

Practical notes:
- `prealloc` is on, which is the right choice for a Proton/game volume.
- A handful of Proton games behave badly on NTFS (case sensitivity, symlinks, sparse
  files). Nothing was changed here; it is recorded so an AI does not assume ext4/btrfs.

## Swap and zram

| Device | Size | Used | Priority |
|--------|------|------|----------|
| `/dev/zram0` | 30.2 G | 1021 M | **100** (preferred) |
| `/dev/nvme0n1p6` | 19.5 G | 0 B | -1 (fallback) |

- zram is configured by **zram-generator**: `/usr/lib/systemd/zram-generator.conf`:
  ```ini
  [zram0]
  compression-algorithm = zstd
  zram-size = ram
  swap-priority = 100
  fs-type = swap
  ```
  i.e. zram sized to **= RAM**, zstd, preferred over the disk swap.
- With a zram-first layout, the kernel should *prefer* compressing anonymous pages into
  RAM rather than paging to disk. That is exactly why swappiness is high here — see next.

### `vm.swappiness = 150` — where it comes from (this is not a mistake)

`/usr/lib/udev/rules.d/30-zram.rules` sets `vm.swappiness=150` when the zram device
initialises. CachyOS ships this on purpose: with zram present, a swappiness **above 100**
tells the kernel to move cold anonymous pages into the zram compressor instead of
writing them to the disk swap. There is **no file in `/etc/sysctl.d/`** overriding it
(that dir is empty), so the udev rule is the sole source. **No change recommended.**

## Writeback tuning (measured)

`vm.dirty_ratio` and `vm.dirty_background_ratio` both read `0`, which looks alarming but
is **correct**: when the byte-based knobs are non-zero the kernel uses those instead.

| Knob | Value |
|------|-------|
| `vm.dirty_bytes` | 268435456 (256 MiB) |
| `vm.dirty_background_bytes` | 67108864 (64 MiB) |
| `vm.dirty_expire_centisecs` | 3000 (30 s) |
| `vm.dirty_writeback_centisecs` | 1500 (15 s) |

This is a deliberate, sane tune: it bounds how much dirty data can pile up, keeping
writeback latency predictable. **No change recommended.**

## Other memory sysctls

| Knob | Value | Notes |
|------|-------|-------|
| `vm.max_map_count` | 1048576 | already raised well past the old 65530 default — good for Proton/Wine |
| `vm.vfs_cache_pressure` | 50 | mildly cache-friendly; fine |
| `vm.overcommit_memory` | (default) | fine |

## Optional, not applied

- `vm.page-cluster=0` is a common zram companion (no read-ahead on a RAM device that is
  already fast). Offered in `11-root-actions.md`.
- The unused `nvme0n1p8` (661 G btrfs) is noted — it is a spare volume if space ever gets
  tight; the games volume is at 89%.
