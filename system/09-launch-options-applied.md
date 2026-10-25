# 09 — Launch options actually applied (2026-10-14)

## The change

While **Steam was closed**, the `LaunchOptions` value was written into

```
/home/maxii/.local/share/Steam/userdata/1145198416/config/localconfig.vdf
```

for every installed Steam game that did **not** already have a non-empty
`LaunchOptions`.

## The uniform string

```
ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_DXVK_LOWLATENCY=1 gamemoderun %command%
```

Rationale and existence-proof for each token: `08-steam-proton-flags.md`.

## Result summary

| Bucket | Count |
|--------|-------|
| Games that got the uniform string | **56** |
| Games left completely untouched (already had real options) | **4** |
| Anti-cheat games deliberately excluded | **3** |
| Total "game" targets | **60** (56 + 4); the 3 anti-cheat titles are counted separately and got nothing |
| Total `LaunchOptions` keys now in the file | 62 |

The 62 keys = 56 new + 4 pre-existing target strings + 2 non-game keys
(`460920`, `2698940`).

## The 56 games that got the uniform string

| AppID | Game |
|-------|------|
| 911400 | Assassin's Creed III Remastered |
| 812140 | Assassin's Creed Odyssey |
| 244210 | Assetto Corsa |
| 805550 | Assetto Corsa Competizione |
| 3058630 | Assetto Corsa EVO |
| 1066890 | Automobilista 2 |
| 2379780 | Balatro |
| 284160 | BeamNG.drive |
| 2881650 | Content Warning |
| 268910 | Cuphead |
| 1222140 | Detroit: Become Human |
| 782330 | DOOM Eternal |
| 1293830 | Forza Horizon 4 |
| 2144740 | Ghostrunner 2 |
| 1145360 | Hades |
| 1048290 | Heavy Rain Demo |
| 2420110 | Horizon Forbidden West Complete Edition |
| 313690 | LEGO Batman 3: Beyond Gotham |
| 829110 | LEGO DC Super-Villains |
| 352400 | LEGO Jurassic World |
| 249130 | LEGO MARVEL Super Heroes |
| 647830 | LEGO MARVEL Super Heroes 2 |
| 405310 | LEGO MARVEL's Avengers |
| 438640 | LEGO STAR WARS: The Force Awakens |
| 285160 | LEGO The Hobbit |
| 214510 | LEGO The Lord of the Rings |
| 332310 | LEGO Worlds |
| 1445790 | Make Way |
| 1238000 | Mass Effect: Andromeda |
| 1369670 | Motor Town: Behind The Wheel |
| 648800 | Raft |
| 304240 | Resident Evil |
| 339340 | Resident Evil 0 |
| 883710 | Resident Evil 2 |
| 952060 | Resident Evil 3 |
| 254700 | Resident Evil 4 (2005) |
| 21690 | Resident Evil 5 |
| 221040 | Resident Evil 6 |
| 418370 | Resident Evil 7 Biohazard |
| 1236300 | Resident Evil Re:Verse |
| 952070 | RESIDENT EVIL RESISTANCE |
| 222480 | Resident Evil Revelations |
| 287290 | Resident Evil Revelations 2 |
| 1196590 | Resident Evil Village |
| 391220 | Rise of the Tomb Raider |
| 526870 | Satisfactory |
| 1326470 | Sons Of The Forest |
| 267530 | The LEGO Movie - Videogame |
| 881320 | The LEGO Movie 2 - Videogame |
| 640590 | The LEGO NINJAGO Movie Video Game |
| 365590 | Tom Clancy's The Division |
| 1225560 | Unravel |
| 1225570 | Unravel Two |
| 1462810 | WRC 10 FIA World Rally Championship |
| 1267540 | WRC 9 FIA World Rally Championship |
| 1953520 | WRC Generations - The FIA WRC Official Game |

## The 4 games left untouched (already had their own strings)

| AppID | Game | Existing value | Verdict |
|-------|------|----------------|---------|
| 2483190 | Forza Horizon 6 | SDL `HIDAPI` rumble set + `MESA_SHADER_CACHE_MAX_SIZE=10G gamemoderun %command%` | **Keep — do not touch.** The SDL set is required for trigger rumble. |
| 1174180 | Red Dead Redemption 2 | `PROTON_PRIORITY_HIGH=1 ENABLE_LAYER_MESA_ANTI_LAG=1 STAGING_SHARED_MEMORY=1 RADV_DEBUG=nggc RADV_PERFTEST=sam,gpl mangohud gamemoderun %command% -skip-launcher` | Left as-is. Contains **2 dead flags** (`PROTON_PRIORITY_HIGH`, `STAGING_SHARED_MEMORY`) — see below. |
| 739630 | Phasmophobia | Mesa set + `PROTON_DXVK_LOWLATENCY=1 gamemoderun %command%` | Left as-is; already close to the uniform set. |
| 601360 | Portal: Revolution | Mesa set + `gamemoderun %command% -skip-launcher` | Left as-is. |

**Decision rationale:** the user wrote these by hand. Silently rewriting someone's
deliberate choices (and FH6's rumble-critical SDL vars) is worse than documenting them.
If normalisation is ever wanted, it is a one-line paste per game.

### Two dead flags and one counterproductive flag found in the pre-existing strings

- `PROTON_PRIORITY_HIGH=1` (RDR2) — **does not exist** in this Proton build. No effect.
- `STAGING_SHARED_MEMORY=1` (RDR2) — **does not exist** here. No effect.
- `MESA_SHADER_CACHE_DISABLE=1` (appears in some of the older hand-written strings) —
  **actively harmful** for stutter; deliberately **not** propagated.

## The 3 anti-cheat games excluded

| AppID | Game | Anti-cheat | Evidence on disk |
|-------|------|-----------|------------------|
| 1245620 | ELDEN RING | Easy Anti-Cheat | EAC runtime present |
| 2290180 | Riders Republic | BattlEye | `RidersRepublic/BattlEye` |
| 2698940 | The Crew Motorfest | BattlEye | `The Crew Motorfest/BattlEye` + `Proton BattlEye Runtime` |

**Why excluded:** the uniform string contains `gamemoderun`, which works by injecting
`libgamemodeauto.so` via `LD_PRELOAD`. Injecting a preload library into an anti-cheat
protected process is exactly the kind of thing anti-cheat software is designed to detect
and can cause a failed launch or worse. These games were left alone.

They *could* safely take the three environment variables alone (those do not inject
anything) if desired — see the note at the end.

## What was NOT done (deliberately)

- No per-game-specific tuning beyond the uniform string (the user asked for system-wide
  wins only).
- No `-skip-launcher`, `-novid`, resolution or other per-game arguments were added.
- No game was given `mangohud` (the global `/etc/environment` already has
  `MANGOHUD=1`; adding it per-game is redundant).

## Rollback

Two clean options:

1. **Restore the whole file from the pre-write backup** (simplest, reverts everything):
   ```bash
   # Steam must be closed first
   cp /home/maxii/.local/share/Steam/userdata/1145198416/config/localconfig.vdf.bak-20261014-172859-launchopts \
      /home/maxii/.local/share/Steam/userdata/1145198416/config/localconfig.vdf
   ```
   (`-launchopts3` is a later backup, taken just before the single Detroit fix.)
2. **Remove only the uniform strings** without touching the pre-existing ones — a script
   is provided: `scripts/rollback-user-level.sh`.

## Adding the env-vars-only string to the anti-cheat games (optional, manual)

If ever wanted, the injection-free subset is:

```
ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_DXVK_LOWLATENCY=1 %command%
```

(no `gamemoderun`). Paste it into those three games' launch options manually.

## Caveat about `gamemoderun` (important, honest)

On **this** machine `gamemoderun` currently contributes very little:

- `gamemoded` runs as a **user** service (there is no system unit), with
  `CapEff = 0` and max-nice 31, so it **cannot renice the game** to a negative nice,
  **cannot** switch the governor, and **cannot** write the GPU clock file.
- The governor is already `performance` system-wide, so GameMode's headline CPU win is
  already taken regardless.

Its remaining effect today is screensaver inhibit. It is harmless, so it was left in the
56 strings. To make it *actually* do something, enable the GameMode item in
`scripts/optimize-system.sh` (system daemon + udev rule + `/etc/gamemode.ini`), or drop
`gamemoderun` entirely (`scripts/rollback-user-level.sh --strip-gamemoderun`).
