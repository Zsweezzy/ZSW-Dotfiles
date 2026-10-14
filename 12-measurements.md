# 12 — Measurements: what was measured, what was NOT

Honesty section. Read this before quoting any number anywhere else in this repo.

## The `borderangle` A/B test was INCONCLUSIVE — do not cite a number

The animated gradient border (`borderangle`) is a continuously-repainting loop, so it was
A/B tested by sampling compositor/GPU busy time during a fixed window:

| Run | Result |
|-----|--------|
| A (animated border) | 6.95% |
| B (static border) | 7.30% |
| C (animated border again) | 7.20% |

**Interpretation: C == B.** The repeat of the "animated" condition landed on the same
value as the "static" one, so the difference between A and B is **noise, not signal**.

Why it was unmeasurable: **Firefox / YouTube was playing the whole time**, keeping the
compositor actively redrawing (GPU ~13% busy, later ~11%). With no idle screen, the
border loop's marginal cost is below the noise floor. The loop only matters on a
*static* screen.

**Conclusion:** the static border was applied because the user chose "make the border
static", and it is a defensible idle-cost choice — but it is **not** a proven FPS win.
If the spin is missed, revert with `borderangle { enabled = true }` (a full restore
option is offered in `13-changelog-2026-10-14.md`).

## What WAS solidly established (with evidence)

| Finding | Evidence |
|---------|----------|
| VRR ended fully off | `diff` vs `.bak-20261014-133556` empty; `grep -c vrr` = 0; `misc:vrr = 0` |
| Animations snappy but on | `animations:enabled = true`; durations table in `07` |
| Lua config still valid | `luac -p` OK; `hyprctl configerrors` empty; `hyprctl reload` ok |
| 56 games got the uniform string | 0 key/value pairs lost; per-target presence asserted; byte-identical re-read |
| `PROTON_PRIORITY_HIGH` / `STAGING_SHARED_MEMORY` don't exist | not found in the Proton script or Mesa libs |
| `ENABLE_LAYER_MESA_ANTI_LAG` exists | layer JSON `enable_environment` |
| `gamemoded` cannot renice / set governor / set GPU clock | `CapEff=0`, max nice 31, no system unit |
| Dominant idle cost is the clip recorder | `gpu-screen-recorder` 170 MB / 5% CPU / GPU 11% / mclk 1249 MHz |
| sched_ext is NOT attached | no `/sys/kernel/sched_ext/root/ops` |
| Machine is already clean/tuned | 0 orphans, 0 failed units, governor performance, etc. |

## Method notes / gotchas for the next measurement

- `hyprctl keyword` does not work with the Lua config parser; use `hyprctl eval`.
- `hyprctl getoption` lacks `misc:vrr`, `misc:damage_tracking`, and per-animation-leaf
  options in this build — validate with `hyprctl configerrors` (expect empty).
- GPU busy: `/sys/class/drm/card1/device/gpu_busy_percent`.
- GPU clocks: `/sys/class/drm/card1/device/pp_dpm_sclk`, `.../pp_dpm_mclk`.
- The machine is **in active use** (Firefox/YouTube + agent) during all measurements, so
  idle-cost numbers are understated in variance; do not trust small deltas.

## FH6 in-game settings found on disk (context, not changed by this repo)

- `Fullscreen 0` (fullscreen off — matches the rule below), `FSR3Mode 1`,
  `UseDynamicOptimization 0`.
- Its stored refresh `0.008333` = 120 Hz. DP-1 is now 144 Hz, so the user may want to set
  144 manually in-game. This is a game setting, out of scope for the launch-options work.

## Hard rule recorded from earlier work (do not violate)

**In-game Fullscreen must stay OFF on this machine.** Exclusive fullscreen stutters
severely here. Borderless/windowed-fullscreen is the correct mode. There is no
"Dynamic Optimisation" toggle in the in-game menu — do not instruct the user to look for
one.
