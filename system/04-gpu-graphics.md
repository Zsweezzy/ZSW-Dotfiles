# 04 — GPU and graphics stack

## Hardware / driver

- dGPU: **RX 7900 XTX** (Navi 31, `1002:744c`), DRM node **`card1`**.
- Driver: **RADV** (Mesa **26.2.4**). No proprietary driver involved.
- `power_dpm_force_performance_level` = **`auto`** (file
  `/sys/class/drm/card1/device/power_dpm_force_performance_level`,
  `-rw-r--r-- root root` -> the **user cannot write it**; GameMode needs a udev rule).
- iGPU Raphael/610M is `card0` and is not used for gaming.

## Shader cache

Mesa's shader cache is what causes "first-run stutter" and re-stutter after a driver
upgrade or cache eviction. Relevant evidence on this machine:

- `MESA_SHADER_CACHE_DISABLE` exists as a Mesa knob — **but disabling the cache is
  counterproductive** for performance. Two of the user's own pre-existing launch
  strings contained `MESA_SHADER_CACHE_DISABLE=1`; that value was **not** propagated
  to the 56 newly-configured games. See `09-launch-options-applied.md`.
- `MESA_SHADER_CACHE_MAX_SIZE` and `MESA_SHADER_CACHE_DIR` exist — raising the cache
  ceiling reduces eviction/recompilation. Offered globally in `11-root-actions.md`.

## Implicit Vulkan layers present

- `/usr/share/vulkan/implicit_layer.d/VkLayer_MESA_anti_lag.json` exists, and its
  `enable_environment` is **`ENABLE_LAYER_MESA_ANTI_LAG=1`**. This is why that variable
  is safe to use: it is the documented enable switch of a layer that is actually
  installed. (Mesa's anti-lag layer reduces input latency by limiting how many frames
  the CPU can queue ahead.)

## MangoHud

- MangoHud is installed and the **global** config lives at
  `/home/maxii/.config/MangoHud/MangoHud.conf` (the only conf MangoHud reads).
- A global `/etc/environment` contains `MANGOHUD=1`, which is why the overlay can appear
  without any per-game flag. Near `/home/maxii/.config/MangoHud/MangoHud.conf` the
  MangoHud log/overlay behaviour is controlled; `autostart_log` was found non-zero at
  some point and is reverted to `0` in the current global conf (logging to disk during
  play costs a little I/O and is not wanted by default).
- Use MangoHud (`Shift_R+F12` default toggle) to verify frame pacing after any change.

## Benchmarks / tools available

- `glxinfo`, `vulkaninfo` — checked presence (used for the driver facts above).
- `MangoHud` — for on-screen frame timing.
- No `radeontop` requirement; GPU busy % read straight from
  `/sys/class/drm/card1/device/gpu_busy_percent`.

## Observed GPU behaviour at idle (with the always-on recorder running)

- `gpu_busy_percent` = **11%** while the user was simply watching Firefox/YouTube.
- sclk 176 MHz (floor) but **mclk active tier 1249 MHz** — the memory clock does not sit
  at its floor because the GPU is continuously encoding the recording feed.
- This is the single biggest *idle GPU* cost on the machine and is attributable to
  `vice` / `gpu-screen-recorder`, not to the desktop. See `10-idle-costs-services.md`.

## Nothing was changed in the GPU stack beyond launch options

No driver, kernel module parameter, or DPM setting was modified. The only GPU-facing
change is the environment variables added to game launch options (and the proposed
global `/etc/environment` additions), plus the optional GameMode udev rule.
