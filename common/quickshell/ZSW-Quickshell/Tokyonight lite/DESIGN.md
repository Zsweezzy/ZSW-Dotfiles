# Design rules — tokyonight

For anyone writing UI here, human or AI. Copy this file anywhere; it is
self-contained.

**The point of this doc:** `Tokyo.qml` already holds every colour, radius and
font, with a comment explaining why each value is what it is. This file is the
*index* — which token for which job, the rules the tree actually follows, and
the traps that cost real debugging time. It deliberately does **not** repeat the
hex values: an AI writing QML here writes `Tokyo.bg`, never `#1e2030`, so a
duplicated table could only ever drift.

---

## The one rule that makes the rest work

**Never write a literal colour, font or radius. Reference the token.**

- 51 hex literals exist in the tree. The 34 in *code* live in `Palette.qml`,
  which `~/.local/bin/theme` regenerates from `~/.config/themes/<slug>/theme.conf`;
  `Tokyo.qml` only maps token names to it. Never edit `Palette.qml`. The other
  17 are inside comments explaining where a value came from.
- Every `font { family: … }` is `Tokyo.fontFamily`. Zero exceptions in 35 files.

```qml
color: Tokyo.bg          // yes
color: "#1e2030"         // no — now two sources of truth for one pixel
```

---

## Tokens — which one for which job

### Surfaces — opaque

| token | use it for |
|---|---|
| `bgDark` | a popup's own fill — the card everything else sits on |
| `bg` | a card *inside* a `bgDark` surface. One step up. |
| `pane` | a flyout panel's fill (Settings, Notification Centre) |
| `paneEdge` | a pane's own outline |
| `hairline` | a rule *inside* a pane |
| `panelFill` | the clock morph's shape |
| `panelHover` | hover on `panelFill` |

**Never invert the pair.** A `bg` card on a `pane`, or a `bg`-darker fill on a
lighter surface, reads as a near-black hole punched through the widget. Both
directions of this bug shipped and were caught by eye, not by a test.

### Chrome — translucent, bar only

`barBg`, `pillBg`, `cellHover`, `activeTint`. These sit on the bar over
whatever wallpaper is behind them, so they carry alpha. A popup surface uses an
opaque token instead — a translucent popup takes its colour from the window
behind it, and the same pane measured two different values over two windows.

### Island — the bar itself

`islandFill`, `islandDim`. The bar is now one near-black capsule at the top
centre (saneAspect's dynamic-island look) instead of floating pills; the
capsule's drop shadow still uses `shadowColor` / `shadowBlur` /
`shadowOffsetY`. `islandDim` is secondary ink inside a panel (calendar headers,
labels), not a surface.

| token | value | notes |
|---|---|---|
| `islandHeight` | 30 | capsule height; the radius is half of it |
| `islandPadH` | 14 | capsule inner padding, each side |
| `islandPanelRadius` | 22 | the panel that grows under the capsule |
| `boxFill` | bg_highlight @ 35% | one step up from `islandFill`: the two boxes inside the control centre. A hover row inside a box uses `panelFill`. |

Workspaces inside the capsule are dots (6px, widening on hover) except the
active one, which is a `blue` numbered pill (22×16, radius 8, 10px bold
`islandFill` text). At capsule size a row of numbers is unreadable; the dots
still say how many workspaces there are.

The app launcher (`Launcher.qml`, Super+R) is a layer surface in the bar's own
process, not an island popup: an xdg_popup of the bar's layer surface never gets
keyboard focus, so its search field could not be typed into. Like the bar, one
instance lives on every monitor (`Variants` in `shell.qml`), and only the focused
one opens. The windows are mapped for the whole session; opening only raises the
input mask and keyboard grab, so there is no process start or layer fade between
the keypress and the card. The capsule widens into the card with the same
`islandPanelRadius` seam as the island's own panels.

A layer surface's `screen` must never change while it runs: repointing it
rebuilds the surface, and Hyprland then delivers no pointer events to the
replacement — the window is drawn but every click falls through it.

### Ink

| token | use it for |
|---|---|
| `fg` | primary text |
| `dim` | secondary text, units, captions |
| `trayGlyph` | glyphs for backgrounded apps |

### Accents — a colour *means* something

`blue` `cyan` `green` `yellow` `red` `orange` `magenta` `purple` `teal` `pink`

The mapping is fixed and load-bearing: **CPU cyan, RAM green, GPU purple, disk
yellow.** A dial, its label and its pill fragment all take the same accent so
the bar and the flyout read as one widget. Do not recolour for variety — a
reader identifies the stat by colour before they read the label.

### Geometry

| token | value | notes |
|---|---|---|
| `pillRadius` / `panelRadius` | 10 | Hyprland `decoration.rounding`. **Two tokens, both 10** — the clock morph interpolates between them, so changing one alone breaks the corner animation. |
| `popupRadius` | 20 | Standalone floating slabs *only* (panels). Widgets nested inside a slab keep 10. The toast opts out the other way: `pillRadius` (10), a card like the panels — a stadium at island scale read bigger than anything else on screen. |
| `barHeight` | 34 | |
| `edgeGap` | 6 | matches Hyprland `gaps_out`, so pills sit as far from the screen edge as windows do |
| `fontSize` | 13 | base body size |
| `flyoutWidth` | 1100 | moonsettings' flyout. `Bar.qml`'s top-edge hover strip is this wide and centred, so the pointer is inside the panel the moment it opens |
| `panelPadH` / `panelPadV` | 16 | every island flyout card; applied by `Panel.qml` and, for the boxes inside one, `Box.qml` |
| `panelGap` | 12 | row gap inside a flyout |
| `islandGap` | 14 | gap between the pills inside the capsule |

---

## Adding an island function

The lite island has **one** flyout: `QuickPanel`. Every pill in the capsule
opens it, so a new bar function goes into the card, not into a new panel:

- a control (a row, a slider, a button) is written inline in `QuickPanel.qml`;
- a section that already exists as a `Panel` is embedded with
  `padH: 0; padV: 0` (`ClockPanel`, `MediaPanel`, `AudioPanel`), so it keeps
  its content and loses only its own card padding.

The card is two `Box`es side by side: left is status (time, now playing,
volume, CPU/RAM), right is the controls. `Box.qml` is the only container —
the card border stays that of the flyout, and a box one step lighter groups its
sections.

A new pill is wired in `Island.qml` with `onClicked: root.toggle(quickPill)`.
A module whose state the card shows passes itself to `Quick` there
(`mediaModule: mediaPill`); `Quick.qml` hands it to `QuickPanel` through its
`panel` component.

The flyout's width is `QuickPanel.implicitWidth`; Island loads it with a
`Loader` and sizes the capsule to the loaded item, so the pill header and the
card cannot drift apart. `tests/test-panel-registry.sh` instantiates the panels
offscreen and checks that width contract, because a panel is otherwise only
created on click.

---

---

## Rules the tree actually follows

**1. Borders are 1px.** All 26 `border.width` in the tree are `1`. Outline
colour is `bgHighlight` on dark cards, `paneEdge` on panes.

**2. Radius may not exceed half the element's height.** Past that a bar stops
being a bar and becomes a lozenge. Three elements clamp with `Math.min()`
already: the workspaces active underline, the timer progress bar, the tray
separator rows.

**3. Type scale.** 9–11px for labels, units and captions; 12–13px for values and
body; 14px+ only for the clock. `letterSpacing` 1.2–1.5 on small caps labels.

**4. Padding is per-file, and currently inconsistent:**

| file | padH / padV |
|---|---|
| AudioFlyout, BrightnessFlyout, NotificationCenter, SettingsFlyout | 16 / 12 |
| **SysFlyout** | **8 / 8** |
| Toast | 10 / 8 |
| TrayMenu | 10 / 8 |
| Tooltip | 20 / 14 |

`padH`/`padV` are declared per file, not shared. The user has asked for the Sys
card to read as tight as their Hyprland windows (`border_size = 2`). **If you
touch one flyout's padding, ask whether the others should move too** — this is
a product decision, not a cleanup.

---

## Traps — these are the expensive ones

- **`Item.left` / `.right` / `.top` / `.bottom` are not numbers.** They return a
  `QQuickAnchorLine` object. Any arithmetic on them is `NaN`, which Qt coerces
  to `0`, so the child gets `width: 0` and paints nothing — no error, just
  invisible text. Use `.x` / `.y` / `.width` / `.height` for arithmetic; use
  `.left` / `.right` only as anchor targets.
- **Every `Text` needs an explicit `width` *and* `elide`.** Otherwise long
  content silently disappears rather than truncating.
- **`TextMetrics` on a live string is not constant.** Measure a fixed
  worst-case sample, never the live text, or the layout jitters every second
  and a 1px difference reads as a doubled glyph.
- **`Repeater` rebuilds every delegate when its model array is reassigned**,
  destroying any `MouseArea` holding a press. Write once on release; never from
  a pointer-move handler.
- **`z` orders siblings regardless of declaration order.** Read the actual `z`,
  not the comment describing it.
- **A failed hot-reload leaves the OLD bar on screen**, so the display always
  looks fine. Only the log tells you. And a failed reload can kill the file
  watcher entirely.

---

## Verifying a change

There is **no qmllint, no qmlls, no qmlformat, no quickshell validate mode.**
Your checks are `bash -n` on scripts, running them, and the reload log.

```sh
scripts/check-reload.sh          # exit 0 = loaded
```

Caveat: that script picks the newest log across *all* quickshell instances, so
an offscreen probe can make it report success about a throwaway. Confirm
against the live bar's own instance when in doubt, and scan from the
`Reloading configuration...` line to **EOF** — warnings raised *during* a load
land between those two lines and a clean-looking check will miss them.

---

## Notifications

Toasts and the notification centre are swaync's, not this tree's: it holds
`org.freedesktop.Notifications` and draws its own layer surfaces. There is no
`NotificationServer` here to fight it for the bus. The island's bell only runs
`swaync-client -t` and polls `-c` for the badge.

The styling lives in `~/.config/swaync/style.css`, which mirrors the island by
hand (`#1a1b26`, `pillRadius`, 11/10px type). Change the toast there, not in QML.

The control centre must sit flush under the capsule: Hyprland's exclusive zone
for the bar already places its surface at the capsule's bottom edge, so
`control-center-margin-top` stays 0 in `~/.config/swaync/config.json`. A margin
there pushes the panel down and opens a strip of the window behind it between
pill and panel. Keep `control-center-width` equal to `Tokyo.notifWidth` (400)
and `layer-shell-cover-screen` on, which is what lets the capsule widen while
the panel is up.

---

## Checklist for new UI here

- [ ] Colours/fonts/radii referenced from `Tokyo`, no literals
- [ ] Accent matches the stat's existing identity (CPU cyan, RAM green, GPU purple, disk yellow)
- [ ] `border.width: 1`
- [ ] Surface radius `pillRadius`, or `popupRadius` only for a standalone slab
- [ ] Every `Text` has explicit `width` + `elide`
- [ ] No arithmetic on `.left` / `.right` / `.top` / `.bottom`
- [ ] Card `height` binding sums its sections, so nothing clips when they grow
- [ ] 4-space indent, no tabs
- [ ] Reload verified, log scanned to EOF