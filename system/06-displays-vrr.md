# 06 — Displays and VRR (what was tried, and why it was reverted)

## Final state (current, measured)

| ID | Output    | Mode                 | Scale | Position | vrr |
|----|-----------|----------------------|-------|----------|-----|
| 0  | DP-1      | 3840x2160 @ 144.00   | 2     | 1920,0   | false |
| 1  | DP-2      | 1920x1080 @ 240.00   | 1     | 3840,0   | false |
| 2  | HDMI-A-1  | 1920x1080 @ 100.08   | 1     | 0,0      | false |

Global option: `misc:vrr = int: 0`.

**VRR is off on every output.** `hyprland.lua` was restored byte-identical to the
pre-edit backup, so it contains **zero** `vrr` lines.

## What happened (the honest history)

1. A VRR-enable experiment was applied to `hyprland.lua`
   (per-monitor `vrr` lines + `misc.vrr`), plus a DP-1 mode change to `@144.00`.
2. The user then asked for VRR to be **fully reverted**.
3. The revert was done by restoring `hyprland.lua` from
   `.bak-20261014-133556`, which is the exact file state **before** any VRR edit.
   Verified: `diff` against that backup is empty, and `grep -c vrr` = 0.

The VRR-edited variant was kept as a separate backup in case it is ever wanted:
`hyprland.lua.bak-20261014-152029-vrr-revert` — this *is* the VRR-ON version
(named for the action it was created for). Do not confuse the two backups:

| File | Is it VRR-on or VRR-off? |
|------|--------------------------|
| `hyprland.lua` | **VRR off** (current, == pre-edit state) |
| `hyprland.lua.bak-20261014-133556` | **VRR off** (the pre-edit reference) |
| `hyprland.lua.bak-20261014-152029-vrr-revert` | **VRR on** (the experiment) |

## Why the user runs without VRR here

- On this multi-monitor layout, mixed refresh rates (144 / 240 / 100 Hz) plus the
  scale-2 4K panel make VRR behaviour inconsistent, and the user asked for it off.
- **Fullscreen must stay OFF in-game** regardless — the user reports exclusive
  fullscreen causes severe stutter on this setup. Borderless / windowed-fullscreen is
  the correct mode on this machine.

### Consequence to remember for one specific game

FH6 (appid `2483190`) stores its own in-game refresh setting on disk as `0.008333`
(= 120 Hz). Now that DP-1 is back at **144 Hz**, that per-game setting may need to be
set manually in-game if the user wants 144. This is a *game setting*, not something
this repo patches.

## Monitor IDs for Hyprland

Hyprland addresses outputs by **name** (`DP-1`, `DP-2`, `HDMI-A-1`) and by numeric ID in
`hyprctl monitors` (`0`, `1`, `2`). Layout, left to right: HDMI-A-1 (0,0), DP-1
(1920,0 scaled 2x), DP-2 (3840,0).
