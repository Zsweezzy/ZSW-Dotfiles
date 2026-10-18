# 02 — OS, boot, kernel

## OS

- **CachyOS Linux** (Arch-based, rolling). `/etc/os-release`: `NAME="CachyOS Linux"`,
  `ID=cachyos`, `BUILD_ID=rolling`.
- **systemd 262** (`262-1-arch`).
- Package footprint: **320 explicitly installed**, **1628 total**, **0 orphans**
  (`pacman -Qdtq` empty). The system is already unusually clean — "strip packages" has
  almost nothing to gain here.
- No failed systemd units (`systemctl --failed` empty).

## Kernel

- **`7.2.10-1-cachyos`**, built `#1 SMP PREEMPT_DYNAMIC`.
- `PREEMPT_DYNAMIC` means the preemption model is chosen at boot; a `preempt=full`
  cmdline argument is therefore *possible* without a kernel rebuild (see below).

## GRUB (bootloader)

- **GRUB is the bootloader** (`/etc/default/grub` exists, `grub-mkconfig` at
  `/usr/bin/grub-mkconfig`). There is no `/boot/loader/entries`, no `limine.conf`,
  no `/etc/kernel/cmdline`, and no `sdboot-manage`.
- **To change the kernel cmdline:**
  1. edit `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`
  2. run `sudo grub-mkconfig -o /boot/grub/grub.cfg`
  3. reboot
  (Do not hand-edit `/boot/grub/grub.cfg`; it is generated.)

## Current kernel cmdline (as booted)

```
BOOT_IMAGE=/@/boot/vmlinuz-linux-cachyos
root=UUID=c7af3f67-984f-45b3-a7fb-6b6ba3180818
rw rootflags=subvol=@
nowatchdog
nvme_load=YES
splash
resume=UUID=afd59cd0-fdce-4a66-8f30-3612358be4f4
loglevel=3
```

### Reading of the current cmdline

| Arg | Meaning | Verdict |
|-----|---------|---------|
| `nowatchdog` | disables NMI watchdog / lockup detector | **already a win** — no need to add `nmi_watchdog=0` |
| `rootflags=subvol=@` | btrfs root subvolume | fine |
| `splash` + `loglevel=3` | quiet boot | cosmetic; `splash` costs a tiny bit of boot time but is harmless |
| `rush`/`mitigations` | *not present* | CPU mitigations are all **on** (see below) |

### Mitigations / hardening state (measured)

| Setting | Value | Meaning |
|---------|-------|---------|
| `kernel.nmi_watchdog` | `0` | watchdog off (matches `nowatchdog`) |
| `kernel.split_lock_mitigate` | `0` | split-lock mitigation **disabled** (a perf tune) — already applied |
| `kernel.perf_event_paranoid` | `2` | default-ish |
| CPU mitigations | all default/on | no `mitigations=off` on the cmdline |

**Optional, user's call, not applied:** adding `mitigations=off` to the cmdline is the
single largest free CPU win available, but it trades away Spectre/MDS-class
hardening. See `11-root-actions.md` (it is offered there with a loud warning, default
answer "no").

**Also optional:** `preempt=full` (works because the kernel is PREEMPT_DYNAMIC) tends to
improve frame-time consistency at a small throughput cost on a desktop that is already
running the `performance` governor.

## Boot-speed note

`NetworkManager-wait-online.service` is **enabled** and only makes boot slower on a
desktop that does not need the network up before login. Safe to disable — listed in
`11-root-actions.md`.

## Sleep / resume

- `resume=UUID=afd59cd0-fdce-4a66-8f30-3612358be4f4` — hibernation resume is wired to a
  swap partition/device.
