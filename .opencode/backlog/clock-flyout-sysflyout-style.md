---
id: clock-flyout-sysflyout-style
title: Detach the clock flyout, restyle it like pc-stats, kill the morph
kind: implementation
status: done

## Delivery

Two commits, both on `clock-pane-codes-align`:

- `0c0bc7b` — detach the flyout from the pill and restyle it like pc-stats.
  `ClockFlyout.qml` 1347 -> 711, `ClockFace.qml` 196 -> 99, `Clock.qml` 114 -> 59.
  Morph deleted rather than bypassed; `PopupAdjustment.None` because `All`
  carries `FlipY`; `Tokyo.clockGlyph` and `Module.hoveredExtra` removed as dead.
- `90210fb` — padding 12 -> 8 and cell gap 10 -> 8 to match SysFlyout, and the
  open animation replaced with the sibling panels' pattern: `t` 0 -> 1 over 260ms
  `OutQuart`, back to 0 over 200ms `InQuart`, both `y` and `opacity` expressions
  of `t`. 462 -> 452 wide.

Evidence, checked directly rather than taken from a worker's report:

- `tests/test-clock-flyout-detached.sh` exit 0, 143 assertions, 0 FAIL.
- `tests/test-forget-button.sh` exit 0 (regression).
- Eight break injections into throwaway copies; the six required ones all go red
  and an unmodified control stays green.
- Live bar loads with zero errors or warnings.

**Not verified:** how it looks on screen. No screenshot tool, and Wayland popups
do not appear in `hyprctl layers`, so placement and the slide distance are
arguments from the geometry, not observations.

### Post-review changes worth remembering

The suite was green on a broken widget until it was made to instantiate
`ClockFlyout` offscreen rather than only the `ClockFace` leaf; it then had to be
reworked twice more as the animation spec changed. Animation bans are by type,
so a `SpringAnimation` cannot re-enter wearing a renamed `NumberAnimation`.
priority: medium
owner: null
depends_on: []
parent: null
external_url: null
---

## Need and objective

The clock flyout is a 1347-line morph: it starts as a copy of the bar pill's
rect and grows into the panel, driving `t` from 0 to 1.04 and back. The face
slides from the readings to a clock glyph while that happens, and two copies of
the face are on screen for the whole open.

The user wants the pc-stats treatment instead: `SysFlyout.qml` is a plain
static popup that appears and disappears. So:

1. The flyout **detaches** from the pill and opens centred at the top of the
   screen. No flush contact, no grow-out-from-under.
2. It is restyled to match `SysFlyout.qml`.
3. The glyph is deleted. So is the time/date slide. Both go away entirely.
4. Animations are snappier — which for a SysFlyout-shaped popup means none on
   open/close.

## Scope

In scope: `ClockFlyout.qml`, `ClockFace.qml`, `Clock.qml`. `Bar.qml` only if the
wiring genuinely has to change.

Out of scope: every other widget. `SysFlyout.qml` is read as the style donor and
must not be edited. `scripts/` is explicitly **not** in this ticket. The
`~/Projects/tokyonight-moon-dotfiles` mirror is **not** in this ticket.

## Acceptance criteria

1. Left-clicking the clock pill opens a popup **centred horizontally at the top
   of the screen**. It does not touch the pill, is not flush under it, and no
   6px gap strip is reserved below the pill.
2. No glyph is ever drawn. The pill shows `HH:mm:ss` over the date at rest, on
   hover, and while the popup is open, and it does not move.
3. Open and close are instant — `visible: !visible`, no tween, matching
   `SysFlyout.qml`. Any `Behavior` left in the three files is `<= 120ms`, the
   same figure `SysFlyout.qml` uses.
4. The popup surface matches `SysFlyout.qml`: outer `Rectangle` on
   `Tokyo.bgDark` with `Tokyo.pillRadius` and a 1px `Tokyo.bgHighlight` border;
   inner cards on `Tokyo.bg` with the same radius and border; section labels
   `pixelSize: 10`, `bold: true`, `letterSpacing: 1.5`; values `pixelSize: 13`,
   `bold: true`.
5. Content is unchanged and still live: clock/timezones, date, uptime and timers
   all render, still from `scripts/clock-panel.sh` and the `TimerState`
   singleton.
6. The morph is gone, not merely bypassed. `grep -n` for `glyphMix`, `settleAt`,
   `openExp`, `swapTravel`, `magnetItem`, `contentIn`, `overshoot` across the
   three files returns nothing.
7. A closed flyout forks nothing — the script poll stays bound to `visible`.
8. `scripts/check-reload.sh` exits 0 after each save.
9. One runnable check fails if 1–3 or 6 regress.

## Technical constraints

- **Quickshell 0.3.1.** `PopupWindow` has `relativeX` / `relativeY` and
  `PopupAnchor` has `adjustment`; that is how a detached, screen-top-centred
  popup is expressed, since a Wayland `xdg_popup` cannot float free. Verify the
  exact semantics against the **0.3.1** docs — the quickshell.org URLs that
  resolve now still serve v0.2.1.
- **4 spaces**, no tabs, `grep -cP '\t'` is 0. Check before inserting.
- Live config only. Never the mirror.
- No branch-switch and no worktree: a branch-switch in this tree has previously
  deleted a file and killed the file watcher.
- Commit with `git commit --only <paths>`. `git commit` alone commits the whole
  index.

## Pre-existing state the worker inherits

- `ClockFace.qml` and `ClockFlyout.qml` carry **222 insertions / 133 deletions of
  uncommitted work from another session**, all of it morph tuning (`clip: true`,
  cross-fade → slide, comment rewrites). The user has approved folding it into
  this commit. Expect it to be overwritten — that is intended, not a conflict.
- `.opencode/orchestrator/learnings.md` and `.opencode/backlog/` are also
  uncommitted. **Do not** stage them, and do not edit them.
- `ClockFace.qml` and `ClockFlyout.qml` should end up substantially shorter than
  they are now. Deletion is the point.