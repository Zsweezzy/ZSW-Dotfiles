# 11 — Root actions (needs sudo — prepared, NOT applied)

Everything below requires root, and this environment has **no passwordless sudo**
(`sudo -n true` -> "a password is required"). So none of it has been applied.

A reviewed, idempotent, individually-revertable script implements all of it:

> **`scripts/optimize-system.sh`**
>
> **RUN THIS YOURSELF:**
> ```bash
> sudo /home/maxii/projects/system/scripts/optimize-system.sh
> ```
> It asks before each item (press Enter to accept the recommended answer), takes
> timestamped backups under `/root/system-opt-backups-<timestamp>/`, and can undo
> everything with `--revert`.

---

## The items, and why

### 1. Global `/etc/environment` additions (recommended: YES)

Current file contains only the PAM header comments plus `MANGOHUD=1`. The script appends a
marked block:

```
# --- system-opt (managed by optimize-system.sh) ---
MESA_SHADER_CACHE_MAX_SIZE=12G
ENABLE_LAYER_MESA_ANTI_LAG=1
PROTON_LOCAL_SHADER_CACHE=1
PROTON_DXVK_LOWLATENCY=1
# --- end system-opt ---
```

- Applies to **every** Vulkan/Proton process, including future games and the three
  anti-cheat games (these are plain env vars, no injection).
- This is the "system-wide" counterpart to the per-game strings, and it is the reason the
  three anti-cheat games can still benefit without `gamemoderun`.
- `MESA_SHADER_CACHE_MAX_SIZE=12G` reduces shader-cache eviction/recompilation. 434 GB
  free, so 12 GB is cheap.
- Revert: the script deletes the marked block.

### 2. `NetworkManager-wait-online.service` -> disable (recommended: YES)

Delays boot waiting for a network that a desktop does not need up before login.
Revert: `systemctl enable NetworkManager-wait-online.service`.

### 3. `/etc/sysctl.d/99-gaming.conf` (recommended: YES)

```
vm.page-cluster = 0
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

- `vm.page-cluster=0` — no read-ahead on zram (it is RAM-speed already); a standard zram
  companion tune.
- `fq` + `bbr` — better throughput/latency for downloads and streams. The script only
  writes these if `bbr` is actually available in this kernel (checks
  `/proc/sys/net/ipv4/tcp_available_congestion_control`).
- **Caveat:** `bpftune` may overwrite network sysctls at runtime. If you want them to
  stick, also disable `bpftune` (item 6).
- Revert: delete the file.

### 4. GameMode, made actually effective (recommended: NO — cosmetic/large)

As measured in `09` and `10`, `gamemoderun` does almost nothing here: `gamemoded` is a
**user** service with `CapEff=0` and max-nice 31, and there is **no system unit**.

This item installs what GameMode needs to actually work:
- `/etc/gamemode.ini` with `[gpu] apply_gpu_optimisations=accept-responsibility`,
  `gpu_device=1`, `amd_performance_level=high`;
- `/etc/udev/rules.d/99-amdgpu-gamemode.rules` granting group write to
  `/sys/class/drm/card1/device/power_dpm_force_performance_level` (requires the user to be
  in group `video`).

Effect: during a game the dGPU jumps straight to the highest performance level instead of
ramping from `auto`. It is a **small** win (1% lows), and it is the only way
`gamemoderun` earns its place in the 56 launch strings.

The alternative is to **remove `gamemoderun`** (`scripts/rollback-user-level.sh
--strip-gamemoderun`). Either is fine; the script defaults to "no" because the win is
marginal and it touches device permissions.

### 5. sched_ext scheduler (recommended: NO — experimental, print-only)

`scx_loader` is running but nothing is loaded, and `scx_lavd` / `scx_bpfland` are
installed. The script **does not** change this automatically; it prints the exact
commands, using the installed `scxctl` D-Bus CLI:

```bash
scxctl list          # show available schedulers
scxctl start  --sched scx_lavd     # try the gaming-oriented scheduler
scxctl stop                        # revert to the kernel's EEVDF
```

(Check `scxctl start --help` for the exact flag spelling in this version.) Test on your
own workload; schedulers help some games and hurt others.

### 6. `bpftune` (recommended: NO — your call)

`systemctl disable --now bpftune.service` if you want your own sysctls to be the final
word. Revert: `systemctl enable --now bpftune.service`.

### 7. Optional service trims (print-only, no action)

The script prints measured sizes and ready commands for `nordvpnd`, `tailscaled`
(on-demand VPN), and repeats the `vice` toggle (which is a *user* service — no sudo
needed). It does not disable them.

### 8. Kernel cmdline (print-only, never auto-edited)

Because the bootloader is **GRUB**, the script prints this exact recipe instead of editing
it:

```bash
# edit GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then:
sudo grub-mkconfig -o /boot/grub/grub.cfg
# then reboot
```

Candidates, with honest trade-offs:
- `mitigations=off` — **largest free CPU win**, but disables Spectre/MDS-class
  hardening. Security decision, entirely the user's call. Default: do nothing.
- `preempt=full` — possible because the kernel is `PREEMPT_DYNAMIC`; tends to improve
  frame-time consistency at a small throughput cost.

`nowatchdog` is already present, so there is no reason to add `nmi_watchdog=0`.

---

## Reverting every root item

```bash
sudo /home/maxii/projects/system/scripts/optimize-system.sh --revert
```

That removes the `/etc/environment` block, the sysctl file, `/etc/gamemode.ini`, the udev
rule, re-enables `NetworkManager-wait-online`, and reloads udev/sysctl. Backups taken
during the run remain under `/root/system-opt-backups-*`.
