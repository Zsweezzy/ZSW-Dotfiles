# 08 — Steam / Proton environment flags (evidence-based)

This file answers one question precisely: **which of the flags people sprinkle into
Steam launch options actually exist on *this* machine?**

The audit was done by inspecting the actual files on disk — not from memory. Any flag
that could not be found in a shipped binary/config was **not** used.

## Launch options format reminder

Steam launch options for a game are stored as the string value of `LaunchOptions` inside
`localconfig.vdf`, under
`UserLocalConfigStore/Software/Valve/Steam/apps/<appid>/LaunchOptions`.

- File: `/home/maxii/.local/share/Steam/userdata/1145198416/config/localconfig.vdf`
- Env vars go **before** the executable, literally `VAR=1 VAR2=1 %command%`.
- **Steam must be closed** while editing this file — Steam rewrites it on exit and will
  clobber external edits made while it is running.

## Flags that EXIST here (verified) — and are safe to use

| Flag | Evidence of existence |
|------|------------------------|
| `ENABLE_LAYER_MESA_ANTI_LAG=1` | `enable_environment` of `/usr/share/vulkan/implicit_layer.d/VkLayer_MESA_anti_lag.json` |
| `PROTON_LOCAL_SHADER_CACHE=1` | referenced in `/usr/share/steam/compatibilitytools.d/proton-cachyos-native/proton` |
| `PROTON_DXVK_LOWLATENCY=1` | referenced in the same Proton script |
| `PROTON_ENABLE_WAYLAND=1` | referenced in the same Proton script (left opt-in, see below) |
| `PROTON_PREFER_SDL=1`, `PROTON_NO_FSYNC=1`, `PROTON_HEAP_DELAY_FREE=1` | referenced in the same Proton script (not used) |
| `mesa_glthread=true` | found in Mesa libs (`libgallium-26.2.4-arch3.1.so`, `libvulkan_radeon.so`) |
| `MESA_SHADER_CACHE_MAX_SIZE`, `MESA_SHADER_CACHE_DIR`, `MESA_SHADER_CACHE_DISABLE` | found in Mesa libs |
| `MESA_VK_WSI_PRESENT_MODE` | found in Mesa libs |
| `RADV_PERFTEST`, `RADV_DEBUG`, `RADV_TEX_ANISO` | found in Mesa libs |

## Flags that DO NOT exist here (verified absent) — should not be used

| Flag | Finding |
|------|---------|
| `STAGING_SHARED_MEMORY=1` | **NOT FOUND** anywhere in the Proton script or Mesa libs. Dead flag on this install. |
| `PROTON_PRIORITY_HIGH=1` | **NOT FOUND** in the Proton script. Dead flag on this install. |
| `AMD_VULKAN_ICD` | **NOT FOUND** as a selector here (the RADV path is in use; not needed) |

These matter because two of the user's *pre-existing* hand-written launch strings
contained `PROTON_PRIORITY_HIGH=1` and `STAGING_SHARED_MEMORY=1`. They were doing
nothing. They were left in place (see `09 — games left alone`) rather than silently
rewritten, but they are flagged there.

## Flags that exist but were deliberately NOT propagated

| Flag | Why not |
|------|---------|
| `MESA_SHADER_CACHE_DISABLE=1` | Present in two pre-existing strings, but disabling the shader cache **causes** stutter. Counterproductive. Not propagated; flagged in `09`. |
| `PROTON_ENABLE_WAYLAND=1` | Valid, but changes the windowing path and interacts with the "no exclusive fullscreen" rule. Left as a per-game opt-in. |
| `PULSE_LATENCY_MSEC` | Audio latency knob, trade-off against crackle. Left as per-game opt-in. |
| `mesa_glthread=true` | Only affects **OpenGL** apps; most games here are Vulkan/DXVK. Left out of the uniform set. |
| `MESA_VK_WSI_PRESENT_MODE=mailbox` | Valid knob; behaviour depends on compositor support and can silently fall back to `fifo`. Left as an opt-in. |
| `RADV_PERFTEST=...` | Most old `RADV_PERFTEST` tokens are default-on now. Not needed in the uniform set. |
| `MESA_SHADER_CACHE_MAX_SIZE` | Better applied **globally** via `/etc/environment` (see `11-root-actions.md`) rather than pasted into every game. |

## The uniform string actually applied

```
ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_DXVK_LOWLATENCY=1 gamemoderun %command%
```

- Three env vars: one Mesa (anti-lag layer), two Proton (local shader cache, DXVK
  low-latency). All three verified to exist here.
- `gamemoderun %command%` wraps the launch so GameMode applies priority/screensaver
  handling. GameMode's governor switch is already moot (governor is `performance`), and
  its GPU-clock control needs a udev rule (offered in `11-root-actions.md`).

## Compatibility tools

- `/usr/share/steam/compatibilitytools.d/proton-cachyos-native/proton` is the Proton
  build installed; it is the source of truth for which `PROTON_*` variables exist.
- `~/.local/share/Steam/config/config.vdf` holds `CompatToolMapping`; FH6 is mapped to
  `proton-cachyos-native` explicitly.
