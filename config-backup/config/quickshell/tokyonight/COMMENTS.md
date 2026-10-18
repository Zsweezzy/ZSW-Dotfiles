# Extracted QML comments

Comments were moved out of the `.qml` files below so the code reads clean.
This file is the design rationale for AI: read it before editing.

## `shell.qml`

```qml
// shell.qml — Tokyo Night Moon bar for Quickshell.
// Launch with:  quickshell -c tokyonight
    // One collector is shared by every bar window, so multiple monitors do
    // not race the same interface-rate state or duplicate external probes.
    // Likewise for brightness: the Hyprland→ddcutil display map is built once
    // here instead of per bar window (a `ddcutil detect` costs seconds).
    // There is no second timer surface. The standalone `TimerWindow.qml` and the
    // `timer` IPC target that drove it (and the SUPER + SHIFT + T bind in
    // hyprland.lua) are gone; the clock flyout's TIMERS pane is the only host of
    // `TimerPanel` now, so the list it can show is the list there is.
    // The notification daemon and the history behind the centre. One for the
    // whole shell: `NotificationServer` claims org.freedesktop.Notifications, and
    // a second claim from another bar window's copy would simply fail, so the
    // server and the list it fills have to be the same object everywhere.
```

## `Bar.qml`

```qml
// Bar.qml — one PanelWindow per screen, replicating the waybar bar.
//
//   window#waybar : height 34, bg rgba(30,32,48,0.9) — rendered transparent
//                   here (no background / border band): the pills float over
//                   the wallpaper, everything between them is see-through.
//   layout        : left  = workspaces | audio | tray
//                   center= clock (time over date, click → ClockFlyout)
//                   right = network | sys (gpu+cpu+ram) | updates
//   module pills  : radius 8, margin 4px 3px (26px tall, 3px from each edge)
//   pill gap      : 12px = 6px bar spacing + 3px margins each side (GTK semantics)
    /// shared Brightness service (shell.qml) — DDC/CI per-monitor luminance
        // ---------- bar chrome ----------
        // No background: the bar strip is fully transparent so the wallpaper
        // shows through between the floating pills. The old underlay (rounded
        // rect + 2px bottom border band, waybar's rgba(30,32,48,0.9) bg) is
        // dropped; Tokyo.barBg/barRadius/barBorderBottom stay defined in
        // Tokyo.qml as the waybar style reference.
        // ---------- shared tooltip popup ----------
        // ---------- left ----------
            // leftMargin = hyprland gaps_out (6): the first pill sits exactly as
            // far from the monitor border as a tiled window's edge. Pills are
            // shifted down (barShiftV) to sit midway between the monitor's top
            // edge and the top border of the first tiled window.
            // Audio lives on the left: volume is a control, not a readout, and
            // the right end of the bar is now all monitor-and-link state.
        // ---------- center ----------
            // One pill for the whole centre of the bar: the clock face, with a
            // now-playing strip (pause, stationary art square, skip) fused into
            // its left edge while a player is active — see Clock.qml. The four
            // things that used to sit beside the time (date, time, uptime,
            // timer countdown) moved into the flyout it opens; the media card
            // joined that flyout too.
            //
            // The pill is not hidden, not faded and not moved while the flyout is
            // up. The flyout is a separate surface hung off `clockAnchor`, at the
            // top of the screen and nowhere near this row, so the two are on
            // different pixels the instant it appears and there is nothing to
            // hide. Hiding it was never more than a workaround for a panel that
            // landed on top of it, and it cost two bugs: `visible: false` is
            // skipped by the layout that positions the pill, and the popup read
            // that pill's anchor at the instant it was shown — so the anchor was
            // read off geometry that was mid-flight and the panel landed up to
            // half a pill off. Opacity fixed that one and left a second: the
            // widget disappeared whenever its panel was open, which is a poor
            // thing for a widget to do when the panel is meant to look like it
            // belongs to it.
        // ---------- right ----------
            // rightMargin = hyprland gaps_out (6): the last pill (updates / cachy)
            // ends exactly gaps_out from the monitor border, mirroring windows.
            // (Was 0 to touch the border; now matches the window gap setting.)
            // Beside cachy-updates on purpose: "there are updates" and
            // "something wants you" are both things that arrived while you were
            // looking at something else, and reading them off two adjacent
            // pills is one glance rather than two.
            // The net icons and the power glyph are one pill now: the links the
            // machine is actually on sit next to the switch that changes them.
            // Last on the right, so the power glyph is against the screen edge.
```

## `Tokyo.qml`

```qml
// Tokyo.qml — Tokyo Night Moon palette + bar geometry.
// Mirrors ~/.config/waybar/style.css (source of truth for pixel fidelity).
    // ---------- palette (tokyonight moon) ----------
// moon red
// moon orange
    // glyph color for TRAYED background apps — opened apps keep pink. This is
    // tokyonight's "comment" blue-gray: clearly distinct from pink, reads as
    // secondary/background, still bright enough for 14px glyphs.
    // ---------- flyout surfaces ----------
    //
    // Opaque, every one of them. This block was built out of translucent
    // washes — the pane a thin blue film over the panel, the rules thin films of
    // the foreground — which meant the panel took its colour from whatever
    // happened to be behind it: the same pane measured #394161 over a terminal
    // and #394162 over a photo viewer, and the hairlines drifted with it. Fixed
    // values, so the panel is the panel.
    //
    // These are what those washes actually composited to, read off the screen
    // rather than computed: each surface over the one it really sits on. It was
    // two rules, not one, while the panel had a header — `headerRule` sat on the
    // panel's own fill rather than on a pane, and so a darker fixed value. The
    // header is gone and took its rule with it, so every rule in the flyout is
    // `hairline` on a pane again and one value does the lot.
    //
    // What they replaced, and why it was wrong: the panes were `bg` (#1e2030),
    // *darker* than the fill they cover, so each read as a near-black window
    // punched through the widget; and the borders and rules were `bgHighlight`
    // (#2f334d), the panel fill's own RGB — a divider drawn in the exact colour
    // of what it divides, 2-3 units apart per channel, i.e. nothing.
    /// the pane's own edge, a step stronger than its interior rules: a card reads
    /// as a card because of its outline, and an outline at rule strength is lost
    /// in the fill on the far side of it
    /// a rule *inside* a pane — over `pane`
    /// "dimmed", for the text that used to borrow the *surface* colour to say so.
    /// Lifted along with the surfaces: #2f334d lettering on a #394161 pane is not
    /// a de-emphasis, it is unreadable, and the zone abbreviations are the one
    /// place in these panes that was dimmed by borrowing the fill.
    // The shape the morph grows — the panel's *own* fill, so the flyout draws
    // this and not `pillBg`, which the bar's pills still use.
    //
    // `pillBg` is rgba(47,51,77,0.9) and the bar's pill resolves to about
    // #2d3049 over the bar, so the panel is within a unit of its own widget at
    // rest either way. What is not negotiable is the *lit* widget, which is
    // opaque #2f334d: the widget does not go away when its panel opens, it sits
    // directly on the panel's top edge for the whole morph, and the joint puts
    // the two fills side by side. At #2c3149 that was a 3-unit step on two
    // touching surfaces — the one place a step this small is actually visible.
    // So the panel takes the pill's raw RGB and the step is gone.
    // Its hover target, and it cannot be `bgHighlight` any more. `pillBg` and
    // `bgHighlight` are the same RGB differing only in alpha, so the morph's
    // hover tint was *purely* an alpha change (0.9 -> 1.0) over whatever was
    // behind — which a mix() between two opaque colours cannot express at all,
    // and an opaque fill is exactly two opaque colours. The highlight therefore
    // has to be a real step in RGB now. It is spent across the morph (see
    // `hoverTint`): a lift at t=0 fading to nothing, which is the whole "this
    // widget lit up and then became a panel" beat. It stays *below* `pane` on
    // purpose — a hover target above the pane would turn the two panes into
    // holes in a lit panel for the frames they are fading in over.
    //
    // #353a55, not the 30-unit #454c65 it was. The panel's own fill is now the
    // widget's lit colour, and the widget is on screen throughout the morph, so
    // the tint is a step between the widget directly above and the panel
    // directly below. 30 units there is a light panel sitting on a dark widget
    // for the first half of every open; 6 units is a lift and nothing more.
    // ---------- bar chrome ----------
// rgba(30,32,48,0.9)
// rgba(47,51,77,0.9)
    // hover highlight for the apps-cluster cells. bgHighlight == pillBg, which
    // made the old hover invisible (it blended into the pill); a clearly
    // lighter indigo reads as "this cell is clickable".
// rgba(130,170,255,0.2)
// 0 0 10px 10px
// 2px solid #2f334d
    // One radius for every surface in the shell: the bar's own bottom corners
    // are `decoration.rounding` (10) out of `~/.config/hypr/hyprland.lua`, and
    // the pills, panels, flyouts, tooltip, tray menu and clock panes all wear
    // that same number so a quickshell surface reads as a Hyprland window.
    // Only *surfaces* — a button or a slider track inside a panel is a
    // different scale of thing and keeps its own radius. The other half of that
    // rule is a ceiling, not a preference: a radius may not pass half the
    // element's height, because past it a bar stops being a bar and becomes a
    // lozenge. Three elements needed that and all three clamp —
    // `Workspaces`' 2 px active underline, `TimerPanel`'s 3 px progress bar and
    // `TrayMenu`'s 7 px separator rows.
    //
    // pillRadius and panelRadius are still two tokens even though they are both
    // 10: the morph's shape interpolates between them (see ClockFlyout), so
    // dialling one of them brings the corner run back. It used to be 8 and 16
    // for exactly that reason; at 10 and 10 the corner does not animate.
    // popupRadius is the one surface radius that is not a Hyprland window: it is
    // the corner of a standalone floating slab — the toast card, the
    // notification centre's panel — which the user's own popups already draw at
    // 20px, the `border-radius` of the SUPER+K launcher panel and the SUPER+N
    // notepad. Those two float free of the bar, so they are allowed to be a
    // shape rather than a continuation of it, and at 10 they read as a bar
    // fragment that happened to drift. It is a separate token rather than a
    // bigger pillRadius because the reverse also matters: anything nested
    // *inside* one of these slabs — a notification row in the centre, an entry
    // in the launcher's list — keeps pillRadius, so the pair still steps down
    // from slab to widget the way the launcher steps from 20 to 12.
// 26
// padding: 0 12px
// workspaces button padding: 0 10px
// margin: 4px 3px
// waybar "spacing"
// 12 — GTK margins stack with box spacing
    // Distance from the monitor border to the outermost widgets. Must match the
    // hyprland window↔screen-edge gap (hyprland.lua: general.gaps_out = 6) so
    // the pills sit exactly as far from the border as the windows.
    // Vertical offset that drops the pills below the monitor's top edge. Window
    // top = 42px (34px bar/exclusive zone + 6px gaps_out + 2px border); exact
    // midpoint 21 felt too close to the windows and 17 too close to the edge,
    // so the pills sit at 19 — slightly above the true middle, tuned by eye.
    // ---------- typography ----------
    // ---------- script locations ----------
    /// scripts live with the config now (self-contained bar; waybar pkg removed)
```

## `Module.qml`

```qml
// Module.qml — a Tokyo Night "pill" module.
//
// Geometry matches waybar: radius 8, vertical margin 4px inside a 34px bar
// (so 26px tall), horizontal padding 0 12px, gap between pills 12px
// (3px module margins + 6px bar spacing, GTK box semantics).
//
// Hover behavior is opt-in via `hoverStyle` because waybar only defines
// hover rules for #workspaces (and #taskbar) buttons — the generic pill
// modules like #clock/#cpu stay visually unchanged on hover.
    // ---------- content ----------
// shown in the shared Tooltip popup on hover
    /// Coloured spans in a row, instead of `text`: a list of { text, color }.
    /// For a pill standing for more than one stat, where each of them keeps the
    /// accent it had as a pill of its own (Sys.qml: gpu purple, cpu cyan, ram
    /// green). One label and one `fg` cannot say that.
    // opt-in hover styling (waybar #workspaces / #taskbar buttons)
    // when false the module ignores hover entirely (e.g. the tray counter)
    /// extra letter spacing on the label (waybar `letter-spacing`).
    /// Default 0.2: Pango rounds each glyph advance to an integer pixel at 1x
    /// (JetBrains Mono: 7.8 -> 8.0) while Qt lays out the exact 7.8px, leaving
    /// every pill ~0.2px/char narrower than waybar. Adding 0.2 gives the same
    /// 8.0px advance per glyph. Modules with an explicit waybar letter-spacing
    /// (e.g. date) override this.
    /// What the paint reads, so appearance never has to test `hovered` directly.
    /// There is one input, which is the honest state of things: the extra input
    /// this used to OR in existed so a module could stay lit while its own flyout
    /// covered the pointer, and the clock flyout no longer covers its pill — it is
    /// anchored to the bar's screen-top marker and opens clear of the bar, so the
    /// bar's MouseArea keeps hearing the pointer for as long as it is really
    /// there. Nothing needs to lie about hover any more.
    // ---------- events ----------
    /// button is one of Qt.LeftButton / Qt.RightButton / Qt.MiddleButton
    /// vertical scroll delta (angleDelta.y), e.g. volume control
                // a fragment with `visible: false` drops out and the row closes
                // the gap — the net pill is two icons that are not both there
    // tooltip wiring (shared popup passed from Bar)
    // Network metrics update while the pointer remains over a pill. Keep an
    // already-open tooltip synchronized instead of showing the first sample
    // until the pointer leaves and re-enters.
```

## `Poll.qml`

```qml
// Poll.qml — repeatedly runs a one-shot script and emits the last line of its stdout.
// Waybar equivalent: custom module with `exec` + `interval`.
//
// The script is started immediately at component load ("interval" ms later for
// subsequent runs). `refresh()` can be called to run it right away — this is the
// replacement for waybar's RTMIN signal refresh.
//
// NOTE on quickshell 0.3.1: Process::onFinished calls streamEnded(stdoutBuffer)
// and then deleteLater()s the QProcess. If a fast one-shot script (e.g. gpu.sh,
// which uses printf without a trailing newline) exits before the final
// readyReadStandardOutput delivers the tail bytes, those bytes are still in the
// QProcess internal buffer and get dropped — intermittently losing the last
// chunk of output. Running through `sh -c "<cmd> ; sleep 0.1"` keeps the
// process alive 100ms after the script writes, so the pipe is fully drained
// before the child exits. Scripts therefore need no trailing newline.
    /// list of command arguments, e.g. ["/path/to/wifi.sh"]
    /// milliseconds between runs (waybar `interval`)
    /// set to false to pause the loop
    /// emitted with the script's stdout (last read line) on every run
    // Quote each argument for sh, then append a settle delay so the final
    // bytes of the script's output drain into the pipe before exit.
```

## `Tooltip.qml`

```qml
// Tooltip.qml — hover tooltip popup styled like the waybar `tooltip` CSS rule.
//
//   tooltip { background-color: #16161e; border: 1px solid #2f334d;
//             border-radius: 8px; color: #c8d3f5; }
//
// One instance per bar (created in Bar.qml); every module shares it through
// `tooltipHost`. Anchored below the hovered module via PopupAnchor.item.
// The 6px gap is transparent padding at the popup's top — avoids QML Margins
// struct assignment issues.
    /// anchor below the given item and show the tooltip
```

## `Focus.qml`

```qml
// Focus.qml — the monitor that has keyboard focus right now.
//
// Quickshell 0.3.1 declares Hyprland.focusedMonitor with a
// `focusedMonitorChanged` notifier that HyprlandIpc never emits, so a binding
// on it evaluates exactly once and then holds that value forever. Measured: it
// reads whichever monitor was focused when the config last loaded — DP-1 when
// this instance started at 11:21, DP-2 after a later reload — and never moves
// again. So it is not "the focused monitor", it is "the focused monitor as of
// the last reload", and every consumer that treats it as live is silently
// wrong. On the toast path that frozen name is what decides which monitor shows
// a notification, so a reload while a different monitor is focused leaves every
// Toast disagreeing with the focus and no toast is shown anywhere at all.
//
// Hyprland emits `focusedmon` on the socket2 event stream for every focus
// change, and that is the only live signal available here, so it is what this
// tracks. The frozen property is kept as the seed so there is a usable name
// before the first focus change arrives.
    /// The focused monitor's name, spelled the way Hyprland spells it: "DP-1".
    /// Referenced unqualified — `Focus.monitorName` — from anywhere in the
    /// config, which is the same shape as Tokyo.qml.
```

## `Workspaces.qml`

```qml
// Workspaces.qml — per-monitor virtual desktop pills.
//
// Matches waybar hyprland/workspaces:
//   format "{id}", sort-by-number, on-click "activate"
//   margin-left: 6px on the container
//   each button: padding 0 10px, margin 4px 3px, radius 8
//     default : bg rgba(47,51,77,0.9)  fg #c8d3f5
//     hover   : bg #2f334d solid        fg #86e1fc   (transition 0.15s)
//     active  : bg rgba(130,170,255,0.2) fg #82aaff + 2px bottom border #82aaff
// For an active+hover button, the `.active` rule wins (it comes after
// `:hover` in the stylesheet) — replicated below.
//
// Gestures (added on top of the waybar behaviour, left-click untouched):
//   left click   switch to that workspace (unchanged)
//   right/middle click  open the brightness flyout for THIS bar's monitor
//   scroll       nudge that monitor's brightness by 5
    /// BrightnessFlyout for this bar's monitor (created in Bar.qml)
    // Width = the pill row (its own left margin is 0 — the bar's edgeGap takes
    // over the spacer role, so the total border→first-pill distance is exactly
    // Tokyo.edgeGap). This also removes the old wsPad*2 dead space: the next
    // module (the tray) sits one normal pill gap (12px) from the counter.
    // The HyprlandMonitor that corresponds to this bar's screen
    // Special workspaces (special:tray, special:magic) are hidden Hyprland
    // scratchpads reached by keybind, not part of normal desktop navigation.
    // They carry negative numeric IDs (special:tray is -98 here), so letting
    // them through rendered a meaningless "-98" pill in the bar. Mirrors the
    // exclusion OpenApps.qml already applies to special:tray windows.
        // waybar's #workspaces margin-left was 6px; now 0 because Bar's
        // edgeGap already provides the exact border spacing.
// 3px + 3px button margins
// waybar button min-width 36px
// bottom underline follows the radius
                // waybar marks `.active` on the focused workspace's button only
                // Focus.monitorName, not Hyprland.focusedMonitor.name: that
                // property's `focusedMonitorChanged` notifier is never emitted
                // in Quickshell 0.3.1, so it is frozen at whatever had focus
                // when the config loaded. See Focus.qml.
                // active underline: border-bottom 2px solid #82aaff
                    // clamped, not 2: at this height a radius of 2 is twice half
                    // the bar, which draws a lozenge rather than an underline
                    // Right/middle are accepted explicitly; a MouseArea only
                    // reports the buttons listed here.
                        // Left keeps waybar's original job.
// handles lua-mode dispatch automatically
```

## `Audio.qml`

```qml
// Audio.qml — the audio pill: sink volume readout, wheel control, flyout.
//
//   format          {icon} {volume}%
//   format-muted    \uf026 {volume}%
//   format-icons    [\uf027, \uf027, \uf028]   (threshold at 67%)
//   click/wheel     opens the AudioFlyout (per-app volume, in/out devices)
//   right/middle    same flyout — there is no separate popup anymore
//   scroll          volume ±5%, clamped to the shared overboost ceiling
//   tooltip         : "{desc} {volume}%" (hidden while the flyout is open)
    // Bind the default sink so its audio properties (volume/muted) are valid.
```

## `Clock.qml`

```qml
// Clock.qml — the bar's centre pill: three virtual boxes of one width, the
// clock dead centre. The now-playing controls live in the left box, the clock
// face in the middle, the weather temperature in the right.
//
// The boxes are always present and always the same width — each is the widest
// of the three contents — and what belongs to a box is centred inside it. The
// pill therefore never resizes and nothing ever moves: a player appearing
// fills the left box, the reading settling fills the right one, and the clock
// stays exactly where it was. One pill, three rooms.
//
// Left-clicking it opens ClockFlyout, a popup that is anchored to the bar
// rather than to this widget — it opens centred at the top of the screen and
// hangs clear of the pill — so nothing here has to move, re-measure or hide
// when it does. The pill stays lit and on screen the whole time, which is why
// it can read as the thing that owns the clock even while the panel is up.
//
// Left-click opens the flyout, so the pill takes `hoverStyle` (it looks
// clickable). The media buttons sit inside the same pill but swallow their own
// clicks: a press lands on their MouseArea, not the Module's, so tapping
// pause or skip never opens the panel.
// it opens a flyout
    // Module's own label stays empty; the face draws the content.
    // The widget's clock. Owned here rather than by the face, and read by the
    // flyout as well (`ClockFlyout.clock`), so the pill's seconds and the
    // panel's seconds are the same Date rather than two Timers started at two
    // instants and free to sit a second apart against the wall clock.
    // The whole content is the centred Row: its width already carries the hPad
    // on each side's worth, so the Row plus Module's own horizontal padding.
        // Three virtual boxes of one width, all present in every state: the
        // strip appears and disappears inside the left box, the reading inside
        // the right one, and the pill never changes size. Each box is the
        // widest of the three contents, so the clock sits exactly dead centre.
        // ---- left: the media strip ----
        // ---- middle: the clock ----
                // The face's own metrics, not the live text: sized off
                // `contentW`, so the pill never resizes on the second. See
                // ClockFace.qml.
                // `hovered`, not `lit`: nothing borrows this pill's hover
                // state any more. The flyout is a separate surface on the far
                // side of the screen, so it never covers the pill and the
                // bar's MouseArea keeps hearing the pointer for as long as it
                // is really there.
        // ---- right: the weather ----
```

## `ClockFace.qml`

```qml
// ClockFace.qml — the clock pill's contents, with no chrome: `HH:mm:ss`,
// at rest, on hover and while the popup is open. One look, and it does not
// move.
//
// It is a separate file because the pill's contents are one measurement and the
// pill's width is cut from it (see `contentW`): the font, the metrics and the
// padding arithmetic live here, exactly once. It has no clock of its own — the
// bar's `Clock` supplies the tick, the same value the popup's CLOCK card reads,
// and the hover.
    /// Set by the host from whatever MouseArea is over the face.
    /// The clock this face reads. Supplied, never owned: the host's timer is the
    /// only tick, so a face built against any other Date disagrees about the
    /// seconds digit.
    /// The widest thing the face can draw, and the number the pill's width is cut
    /// from. Measured rather than read off the live text, and the reason is
    /// worth keeping: Qt rounds each character's advance separately, and it does
    /// not think this font's digits are all the same width. Measured over every
    /// time there is, `HH:mm:ss` ranges 62..64px on the seconds alone (`00:00:00`
    /// is 63, `00:00:01` is 64). A face sized off its own live text is therefore
    /// a pill that resizes once a second, which re-runs the bar's layout and
    /// slides the clock sideways. One pixel of disagreement between the pill's
    /// width and its text is what reads as a doubled clock.
    ///
    /// `timeWorst` is the widest the time can get, so the width is a constant.
    /// Re-measure it if the time's format or the font ever changes.
    // The time, vertically and horizontally centred in the pill. The height is
    // declared rather than left to the font's line box, so the numerals sit in
    // the middle of the pill and not at its top.
        // Cyan on hover, like every other label in the bar, and on the same
        // 120ms the popup's own hover runs at.
    // Measured rather than implicit, and read by the pill's own width: a `Text`
    // nested in an Item reports its width only after layout, and a binding that
    // reads it during the first polish is how pills end up a character short.
```

## `Sys.qml`

```qml
// Sys.qml — GPU, CPU and RAM in ONE pill (they were three).
//
// Each stat keeps the colour it had on its own pill — purple / cyan / green —
// so this uses Module's `fragments` (coloured spans in a row) rather than its
// single-colour `text`. Each span is "icon + number": a GB figure where the
// kernel gives us one (VRAM, RAM), the utilization where it does not (the CPU).
//
// The dials live in the flyout (SysFlyout.qml), and there is no hover
// tooltip: the pill answers "how much" and the click answers "how much and of
// what", which is the same split Net.qml makes.
    /// SysFlyout to toggle (created in Bar.qml)
    // Plain properties, not readonly: the Poll handlers below write them.
// %
// GiB allocated
// GiB total
// %
// current clock
// GB
// GB
// %
    // disk: free space on / plus the throughput over it. The rates are the
    // difference between consecutive diskstats samples — see disk.sh for why
    // the subtraction happens here and not in the script.
// GB
// GB
// % used
// bytes/s
// bytes/s
    // The heaviest processes right now, one row per pid, sorted by the script.
    // Reassigned (never mutated) on every poll: the Repeater in SysFlyout.qml
    // rebuilds its delegates on write, so a list that was mutated in place
    // would keep the same objects and lose the per-row kill state.
    // gpu.sh prints " n/a" on a card with no amdgpu counters, and gpuVram stays
    // 0 there — so the same expression that prints the VRAM figure falls back
    // to the utilization on its own, no second code path.
    // No hover tooltip. Module shows nothing for an empty one, and the dials are
    // one click away — the same reasoning as Net.qml.
    // ---------- flyout ----------
    /// the flyout's sample is a second old by the time the panel is up
    // ---------- parsers ----------
    /// gpu.sh: " 26% 1/24GiB" (leading space, no trailing newline)
    /// cpu.sh: pill | "CPU: N%" | "4.50 GHz" | per-core grid rows | legend.
    /// Only the first three are read; the grid has no home now that the pill
    /// has no tooltip (see the header).
    /// mem.sh: pill | "used/total GB (N%)" | top-10 process rows. The header is
    /// all that is read; the rows have no home now that the pill has no tooltip.
    /// disk.sh: "718.4|841.1|15|41431857|27052588" — free GB, total GB, used %,
    /// cumulative sectors read, cumulative sectors written. The rates are the
    /// difference between the last two samples over the wall time between them,
    /// so the `refresh()` on open (which is not on the poll boundary) still
    /// shows the true MB/s instead of a spike or a stall.
            // 512-byte sectors (the diskstats unit, fixed by the kernel ABI),
            // kept in bytes/s so the flyout can pick its own unit the same way
            // network-monitor.sh does for the link rates.
    /// procs.sh: "TOP 12|pid|name|cpuPct|ramMB|..." — the count first, then rows
    /// of four. Two bail-outs, both keeping the list that is already on screen:
    /// a header that is not `TOP <n>` (script died before printing anything) and
    /// a header with no complete row behind it (died part-way through one). A
    /// blank list reads as "nothing is running", which is a lie; the previous
    /// list reads as slightly stale, which is true.
```
