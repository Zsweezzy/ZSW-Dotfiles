# 03 — CPU, scheduler, power

## Frequency scaling (measured)

| Knob | Value | File |
|------|-------|------|
| Driver | `amd-pstate-epp` | `/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver` |
| Governor | `performance` | `.../scaling_governor` |
| EPP | `performance` | `.../energy_performance_preference` |
| Boost | `1` (on) | `/sys/devices/system/cpu/cpufreq/boost` |
| `amd_pstate` status | `active` | `/sys/devices/system/cpu/amd_pstate/status` |
| `prefcore` | `enabled` | `/sys/devices/system/cpu/amd_pstate/prefcore` |

**Conclusion: the CPU is already tuned for maximum performance.** Governor and EPP are
both `performance`, boost is on, and amd-pstate is active. There is nothing to gain by
adding a "set governor to performance" step at login — it is already system-wide and
persistent (it is set before the desktop starts).

### Consequence for `gamemoderun`

GameMode's classic CPU win is switching the governor to `performance` during a game.
That win **is already taken**, so on this machine `gamemoderun` contributes mainly:
- process **priority** (renice of the game),
- **screamsaver inhibit**, and
- optionally **GPU performance level** (only if a udev rule is installed — see below).

So the launch-option additions are still useful, but they are not the big CPU lever
people assume; that lever is already pulled.

## X3D cache layout — matters for pinning

- `cpu0-7`, `cpu16-23` -> **96 MiB** L3 (3D V-Cache CCD).
- `cpu8-15`, `cpu24-31` -> **32 MiB** L3.

Games that fit in cache benefit from the 96 MB CCD. Do **not** pin games to `cpu8-15`
on this chip.

## Scheduler

- **Scheduler in use: EEVDF (the kernel default).**
- `scx_loader.service` is **active and enabled**, and `scx_lavd`, `scx_bpfland`,
  `scx_rustland` are all installed at `/usr/bin` — **but no BPF scheduler is attached**:
  `/sys/kernel/sched_ext/root/ops` does not exist, and `/etc/scx_loader/config.toml`
  is absent, so the loader is sitting idle waiting to be told what to load.
- This is a real, unused lever. `scx_lavd` is the CachyOS/gaming-oriented sched_ext
  scheduler. Enabling it is offered in `11-root-actions.md` (with a one-line revert to
  EEVDF). It is *not* applied here because it changes global scheduling behaviour and
  should be A/B-tested on the user's own workload.

## Auto-tuning daemon — `bpftune`

- `bpftune.service` is **active** (running 5+ hours). It is Oracle's BPF auto-tuner and
  **rewrites kernel sysctls at runtime**, mostly networking — e.g. journal shows it
  changing `net.ipv4.ipfrag_high_thresh` `5242880 -> 6553600`.
- Implication: if you hand-tune network sysctls, `bpftune` may override them. If you add
  the BBR/FQ sysctls from `11-root-actions.md` and want them to *stick*, consider
  disabling `bpftune`, or accept that it only touches things it thinks are under-tuned.
- It is a 7.8 MB RSS process; the cost is small.

## Power profiles

- `power-profiles-daemon` is **not enabled** as a system service, but it is running
  (D-Bus activated) and `powerprofilesctl get` returns **`performance`**.
- So the active power profile is `performance` — consistent with the governor/EPP.
- There is no conflict to fix, but note this daemon is *not* the thing setting the
  governor; the governor was already `performance` before it started.

## Bottom line for CPU/scheduler work

1. Nothing to do for frequency scaling — already maxed.
2. Optional real lever: enable an sched_ext scheduler (`scx_lavd`) — user's call.
3. Optional: decide whether `bpftune` should be allowed to keep tuning sysctls.
