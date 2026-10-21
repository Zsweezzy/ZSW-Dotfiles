# hyprland.lua comments

All comments stripped from `hyprland.lua` (same directory) on 2026-10-20, kept in
file order so this file can be read alongside the config. The `---- SECTION ----`
banners remain in `hyprland.lua` and match the `##` sections here. Each block is
verbatim (including `--`) with an anchor to the code line it sits against;
`L<n>` line numbers refer to the pre-extraction file (backup:
`hyprland.lua.bak-20261020-commentstrip`). A block that looks like code is
*commented-out/disabled* config -- not active.

Later the same day the config was slimmed to minimal form: stock-default
restatements and dead template blocks were removed (empty `plugin` config,
`epic-mouse-v1` device, master/scrolling configs for layouts never used, empty
`kb_*` fields, resize/tearing/opacity/shadow/blur default restatements, unused
curves), and SUPER+R now runs `rofi -monitor DP-1 -show drun` directly instead
of `scripts/rofi-toggle.sh` (deleted from ~/.config/hypr/scripts and the
dotfiles config-backup). Comments that documented only those removed lines are
gone from this file too.

## MONITORS

> **L7** before `hl.monitor({`

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Left:  ViewSonic VA270-FHD (HDMI-A-1) -- 1920x1080 @ 100 Hz

> **L15** before `hl.monitor({`

-- Center: Gigabyte M28U (DP-1) -- 4K @ 144 Hz, 2x scale (same as KDE)

> **L23** before `hl.monitor({`

-- Right: AOC 27G2ZNE (DP-2) -- 1920x1080 @ 240 Hz

## MY PROGRAMS

> **L35** before `local terminal = "kitty"`

-- Set programs that you use

> **L51** before `-------------------`

-- HyprCapture removed in favor of grim + slurp (no plugin, avoids plugin/GL crash).

## AUTOSTART

> **L59** before `hl.on("hyprland.start", function()`

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notification daemons, status bars, etc.)

> **L60** on `	hl.exec_cmd("hyprpaper")`

-- wallpaper daemon

> **L61** on `	hl.exec_cmd("quickshell -c tokyonight")`

-- status bar (quickshell tokyonight bar; waybar config backed up in gh:Zsweezzy/waybar-dotfiles).

> **L70** before `	hl.exec_cmd("systemctl --user start hyprpolkitagent")`

	-- hl.exec_cmd("openrgb --startminimized") -- RGB control; disabled (msi-rgb.service also exists but is broken)
	-- Apollo: Moonlight GameStream server. Start the unit, not the binary, because
	-- its ExecStartPre settle delay and Restart= are part of the behaviour, and the
	-- xdg-autostart target it is enabled against never activates under Hyprland.
	-- hl.exec_cmd("systemctl --user start apollo") -- Moonlight gamestream; disabled, start on demand
	-- polkit auth agent: the password prompt pkexec needs (Shelly GUI, etc.).
	-- Start the unit, not the binary, because the graphical-session.target it is
	-- enabled against never activates under Hyprland.

> **L72** before `	hl.exec_cmd("/home/maxii/.local/bin/hypr-shortcut-launcher --background")`

	-- Warm the shortcuts/apps launcher so Super+K only has to reveal it.

> **L81** before `	hl.exec_cmd("/home/maxii/.local/bin/neru launch")`

	-- Clipboard history (cliphist) runs as the systemd user units
	-- cliphist-text/cliphist-image; not started here so the watchers survive
	-- Hyprland restarts.
	-- Neru: keyboard-driven hints (Ctrl+Shift+Space). Absolute path because
	-- autostart runs with a minimal environment and ~/.local/bin is not
	-- guaranteed to be on PATH.

> **L88** before `	hl.exec_cmd("mkdir -p \"${XDG_RUNTIME_DIR:-$HOME/.cache}\"; flock -n \"${XDG_RUNTIME_DIR:-$HOME/.cache}/hypr-session-autosave.lo…`

	-- hl.exec_cmd("/usr/bin/opendeck --hide") -- OpenDeck stream controllers; disabled
	-- Autosave the session every 5 minutes so a snapshot survives a crash or a
	-- hard power-off that never reaches the shutdown hook. flock -n starts it
	-- exactly once even though this config runs twice at startup (see below);
	-- a second copy exits immediately. Lock lives in the user runtime dir, not
	-- /tmp, so another local user cannot pre-create/hold it and kill autosave.

> **L96** before `	hl.exec_cmd("sleep 2 && hyprctl reload")`

	-- ponytail: workaround, Hyprland 0.56.2 executes this config file twice at
	-- startup, so every hl.bind lands in the bind list twice and one SUPER+Q
	-- ran kitty twice (the keybind manager fires every matching bind). A reload
	-- rebuilds the list from a fresh lua state in a single pass and does not
	-- re-fire hyprland.start, so autostart stays single. Delete this once
	-- upstream stops loading the config twice. sleep 2 so the reload lands
	-- after startup monitor setup.

> **L105** before `hl.on("hyprland.shutdown", function()`

-- Snapshot the session when the compositor shuts down (SUPER+M logout, or a
-- logout-then-poweroff/reboot), so the next restore reflects what was open at
-- exit. This is Hyprland's exec-shutdown hook -- it runs while Hyprland is still
-- up, so hyprctl still answers. Best-effort: the 5-minute autosave started in
-- hyprland.start is the guarantee if the hook never fires. Restore itself stays
-- manual (SUPER+CTRL+R).

## ENVIRONMENT VARIABLES

> **L116** before `hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")`

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor matching KDE (kcminputrc): Bibata-Modern-Classic @ 22px

> **L123** before `hl.env("HYPR_LAUNCHER_TERMINAL", terminal)`

-- Terminal the Super+K launcher opens a command in. Same variable as the
-- SUPER+Q bind, so changing `terminal` above moves both at once.

> **L128** before `hl.config({`

-- Render XWayland apps (ONLYOFFICE, Wine, etc.) at native 1x instead of
-- texture-scaling them on the scaled 4K monitor. Text stays sharp; these apps
-- appear smaller on DP-1 (scale 2) but full-size on the 1080p monitors.

> **L136** before `hl.env("QT_QPA_PLATFORMTHEME", "kde")`

-- Qt/KDE apps (Kate, Dolphin, Konsole…) read kdeglobals (TokyoNightMoon)
-- instead of rendering light; also via ~/.config/environment.d/qt.conf

> **L141** before `hl.env("GTK_USE_PORTAL", "1")`

-- GTK apps otherwise draw their own GNOME file picker in-process; this sends
-- them through xdg-desktop-portal, which we point at the KDE chooser
-- (~/.config/xdg-desktop-portal/portals.conf). Needs an app restart.

## PERMISSIONS

(The `---- PERMISSIONS ----` banner was removed from `hyprland.lua` on 2026-10-20 —
nothing under it was active config. The entries below stay as reference.)

> **L161** before `-----------------------`

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

## LOOK AND FEEL

> **L166** before `hl.config({`

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

> **L168** on `		gaps_in = 3,`

-- was 5: 2px smaller space between windows

> **L169** on `		gaps_out = 6,`

-- was 20: same as gaps_in, windows sit close to monitor edges

> **L177** before `			active_border = { colors = { "rgba(82aaffee)", "rgba(ff9e64ee)" }, angle = 45 },`

			-- Tokyo Night Moon palette, same 45° colorflow gradient:
			--   blue   #82aaff  (moon blue)   -> replaces #33ccff
			--   orange #ff9e64  (moon orange) -> replaces #9ece6a green

> **L178** on `			inactive_border = "rgba(2f334daa)",`

-- moon bg_highlight #2f334d

> **L202** on `			color = 0xee16161e,`

-- tokyo night moon bg_dark #16161e

> **L227** before `hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })`

-- Durations were cut ~45% on 2026-10-14 for a snappy feel (system perf pass).
-- `speed` is a DURATION in deciseconds, so smaller = faster.
-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

> **L234** before `hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })`

-- Default springs

> **L256** before `hl.animation({ leaf = "borderangle", enabled = false })`

-- Continuously rotate the active border's gradient angle. The `border` leaf
-- above only animates the colour *switch* speed; this is the spinning part.
-- `style = "loop"` is what makes it rotate forever -- `once` (the default) only
-- animates on a focus change.
--
-- Only gradients have an angle to rotate, so this applies to active_border
-- (a blue->orange 45deg gradient) and leaves the solid inactive_border alone.
-- `speed` is the DURATION in deciseconds, not a rate: 1 = 100ms per turn.
-- So 2 = 200ms/turn (5 turns a second), 40 = 4s/turn. Bigger = slower,
-- same as every other animation leaf.
--
-- Disabled 2026-10-14 (system perf pass).  `style = "loop"` made Hyprland render
-- a new frame on EVERY vblank of the fastest attached panel -- DP-2's 240 Hz --
-- permanently, even with nothing moving on screen.  That is a continuous GPU
-- wakeup.  The border is now a static gradient.
-- Middle ground if the spin is missed: style = "once" (rotates only on a focus
-- change; zero cost at rest).  Full `loop` is the only option that costs frames
-- while idle, so do not put it back without a reason.

> **L265** before `hl.animation({ leaf = "layers", enabled = true, speed = 0.6, bezier = "easeOutQuint" })`

-- Keep layer-shell fades snappy, including the launcher's overlay transitions
-- (0.6 deciseconds is 60ms).

> **L303** before `hl.animation({`

-- Super+S is the magic scratchpad (SUPER toggles special:magic, SUPER+SHIFT+S
-- sends a window into it). `specialWorkspace*` is unset in the tree above, so it
-- inherits `workspaces` -- which is `fade` here, and a scratchpad that just
-- materialises in place reads as a glitch rather than as an arrival.
--
-- `slidevert bottom` is the forced-side form: the second token picks the sign
-- rather than the axis, so "bottom" means +Y coming in (fly up from the bottom
-- edge) and the outgoing leg needs "top" to send the workspace back down and
-- out of the same edge it arrived through. Token order is load-bearing --
-- WorkspaceAnimationController reads args[1] for the side and the *last* token for
-- the travel percentage -- so any percentage would have to go after the side, and
-- the wiki's "slidevert 20% bottom" order silently drops it and slides sideways.
--
-- There is no switch for the fade. Hyprland hardcodes alpha 0->1 on the way in
-- and 1->0 on the way out for every special workspace whatever the style is
-- (WorkspaceAnimationController.cpp), and alpha shares the one animation config
-- with the render offset, so style cannot decouple them. easeOutQuint is the
-- lever: its output is ~0.9 by a third of the way through, so opacity is
-- effectively full while the window is still travelling and the dissolve is not
-- there to see. A spring is deliberately avoided -- its overshoot bounces the
-- alpha as well as the offset.
--
-- Scale on top of the travel is not available here, and it is not a config miss.
-- One leaf carries one style, and the special-workspace controller only animates
-- two things for the whole workspace: alpha and a render offset (translation).
-- There is no scale channel, and the per-window styles that do scale -- popin 85%,
-- gnomed -- live on the window's own map/unmap controller, which a special
-- workspace toggle never runs. So it is travel or scale, not both: this is the
-- travel. For the scale instead, the scratchpad would have to stop being a
-- special workspace and open as a normal window under `animation = popin 85%`.

> **L332** before `hl.config({`

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more

> **L334** on `		preserve_split = true,`

-- You probably want this

> **L361** before `local splitCheckPending = false`

-- Force a side-by-side split whenever a workspace holds exactly two windows.
-- Dwindle picks a split direction from the node's W/H ratio, but
-- `preserve_split` above then keeps whatever it got: a workspace that once held
-- its windows top-and-bottom (or that had the split rotated by hand) stays that
-- way at two windows, where the pair should read as two columns.
--
-- "Exactly two" is every window on the workspace, floating and fullscreen
-- included: a third window of any kind means the layout is left alone, and so
-- does a floating window paired with a single tiled one (there is no two-way
-- split to fix).
--
-- Fires on the events that change how many windows a workspace has, then
-- checks 150 ms later so the layout pass and the window geometry have settled
-- (at window.open the box is not laid out yet). The check is idempotent and a
-- single one is kept pending at a time, so a burst -- session restore opens
-- windows back to back -- collapses into one.
--
-- `togglesplit` has no window argument: DwindleAlgorithm::layoutMsg() reads the
-- *focused* window, so only the active workspace can be corrected. A background
-- workspace is fixed the next time it becomes active -- that is what the
-- workspace.active hook is for -- so the fix also cannot fight SUPER+J until you
-- leave the workspace and come back. The split is only flipped when it is
-- clearly stacked, never when the geometry is ambiguous (pseudo-tiled, grouped).

> **L387** before `	if math.abs(tiled[1].at.x - tiled[2].at.x) < 2 then`

	-- Side by side = the two boxes share a top edge; stacked = they share a
	-- left edge. Neither matching means something this check does not model,
	-- and a toggle would be a guess.

## MISC

> **L428** on `		force_default_wallpaper = 0,`

-- Set to 0 or 1 to disable the anime mascot wallpapers

> **L429** on `		disable_hyprland_logo = true,`

-- If true disables the random hyprland logo / anime girl background. :(

> **L430** on `		disable_splash_rendering = true,`

-- disable Hyprland's random splash text on background

## INPUT

> **L457** before `		sensitivity = -0.3,`

		-- Pointer settings mirroring KDE (kcminputrc):
		--   PointerAcceleration=-0.400  -> libinput pointer speed -0.4
		--   PointerAccelerationProfile=1 -> flat (no acceleration)
		-- Bumped one tick faster, then half a tick slower: -0.4 -> -0.2 -> -0.3

> **L457** on `		sensitivity = -0.3,`

-- -1.0 - 1.0, 0 means no modification.

## KEYBINDINGS

> **L483** on `local mainMod = "SUPER"`

-- Sets "Windows" key as main modifier

> **L488** before `local function describedBind(key, dispatcher, description, options)`

-- Lua-backed Hyprland bindings are reported by hyprctl as __lua with an
-- internal numeric action id. Provide descriptions so the launcher can show
-- what each shortcut does instead of that implementation detail.

> **L495** before `describedBind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), "Open terminal")`

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more

> **L497** before `describedBind(`

-- SUPER + K = searchable Hyprland shortcuts and running-app switcher

> **L507** before `describedBind(mainMod .. " + C", hl.dsp.window.kill(), "Kill focused window")`

-- SUPER + C = force-close the focused app (SIGKILL, no "you sure?" prompt).
-- hl.dsp.window.kill() kills the process instead of sending a graceful close
-- request, so apps can't show save/close confirmations.

> **L512** before `describedBind(mainMod .. " + SHIFT + C", hl.dsp.window.close(), "Close focused window")`

-- SUPER + SHIFT + C = graceful close: ASK the focused app to shut down, so an app
-- that supports the request can prompt to save. An app that ignores it is killed
-- by the compositor regardless — silently, since this bind says nothing.

> **L524** before `describedBind(mainMod .. " + T", hl.dsp.exec_cmd("steam"), "Open Steam")`

-- SUPER + D = launch a second copy of the app in the focused window, on the
-- current workspace, via that window's own command line rather than its class
-- name. Steam moved to SUPER + T only because this chord was taken; whether a
-- Steam window survives the script is incidental to the guard it runs, which
-- refuses whatever the host cannot resolve and knows nothing about Steam.

> **L526** before `describedBind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("spotify"), "Open Spotify")`

-- SUPER + SHIFT + M = Spotify. S itself is spoken for by the magic workspace.

> **L531** before `describedBind(mainMod .. " + I", hl.dsp.exec_cmd(terminal .. " -e hypr-settings"), "Open settings")`

-- SUPER + I = hypr-settings, the terminal UI for the settings the bar does not
-- put on screen (monitors, audio devices, keybinds, Hyprland options). It is an
-- ordinary foreground TUI, so the bind has to open a terminal itself; `terminal`
-- is the local defined at the top of this file.

> **L551** before `describedBind(mainMod .. " + F10", hl.dsp.exec_cmd("shadowclip"), "Open shadowclip")`

-- SUPER + F10 = shadowclip window (ShadowPlay-like replay buffer/recording UI).
-- Deliberately NOT bare F8/F9/F10: those are shadowclip's own evdev hotkeys for
-- record/clip/screenshot and work while the window is unfocused, so a Hyprland
-- bind on the same bare key would fire alongside the app and double-trigger.

> **L562** before `describedBind(`

-- ALT + Tab = free the cursor from whatever is holding it.
-- hl.dsp.release_input_capture ends a wlr-input-capture session, and the only
-- things that create one are compositors-as-clients (Apollo/Steam Remote Play,
-- RDP/VNC) -- so this chord is dead weight for a locally launched game like
-- Detroit: Become Human, which traps the cursor through Wine's own fullscreen
-- pointer clip instead, and nothing in Hyprland releases that except a focus
-- change. See the note below on what to use for the game.
--
-- allow_input_capture is load-bearing: without it the bind is not dispatched
-- while a client holds an input grab.

> **L573** before `describedBind(`

-- Clipboard history (cliphist): SUPER + V opens history in rofi with image
-- thumbnails; picking an entry copies it back to the clipboard (paste with Ctrl+V)
-- The pipeline lives in scripts/clipboard.sh: Hyprland exec does not keep a
-- multi-word command line intact.

> **L579** on `describedBind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize focused window")`

-- fills monitor, keeps gaps + borders

> **L580** on `describedBind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(), "Toggle fullscreen")`

-- fills monitor, no gaps/borders

> **L581** on `describedBind(mainMod .. " + J", hl.dsp.layout("togglesplit"), "Toggle split layout")`

-- dwindle only

> **L584** before `describedBind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), "Focus window left")`

-- Move focus with mainMod + arrow keys

> **L593** before `describedBind(`

-- Rearrange windows with the keyboard:
--   SUPER + SHIFT + arrows = move focused window in a direction
--     (works even when fullscreen: script unfullscreens, moves, refullscreens)
--   SUPER + ALT + arrows   = swap focused window with its neighbor

> **L621** before the `print` bind below

-- Screenshots
--   Print       = active monitor only, instant and silent (grim, no window)
--   SHIFT+Print = region select (slurp + grim)

> **L636** before `describedBind(`

-- SUPER + Print = open the most recent screenshot with qView

> **L647** before `for i = 1, 10 do`

-- Switch workspaces with mainMod + [0-9]
-- Send active window to a workspace without following it with mainMod + SHIFT + [0-9]
-- Move active window to a workspace and follow it with mainMod + CTRL + [0-9]

> **L648** on `	local key = i % 10`

-- 10 maps to key 0

> **L663** before `describedBind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), "Toggle magic workspace")`

-- Example special workspace (scratchpad)

> **L679** before `describedBind(`

-- Manual session snapshots. S saves every window's workspace/geometry plus the
-- monitor layout; R restores them. Restore never closes a window: with windows
-- already open it retiles the open ones onto the saved workspaces, and with none
-- open it launches the snapshot's apps. Exact pixel geometry is kept while the
-- monitor set is unchanged, otherwise only the tiling is restored. A snapshot is
-- also taken every 5 minutes and on shutdown -- see hyprland.start. Logic lives
-- in ~/.config/hypr/scripts/hypr-session.rs, compiled to
-- ~/.local/bin/hypr-session (a wrapper over hyprsession); nothing here needs to
-- be sourced.

> **L700** before `describedBind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = 10 }), "Focus workspace 10 (mouse)")`

-- The NZXT Lift Elite's two thumb buttons. Codes read off the raw evdev stream
-- on /dev/input/event2 rather than guessed: 276 (BTN_EXTRA) is the front button,
-- 275 (BTN_SIDE) the back one. Hyprland has no per-device binds, so these are
-- global -- but no other attached mouse emits 275/276 (the GMMK trackball module
-- declares them and never sends them).
--
-- The workspace chords reuse the dispatchers from the SUPER + [0-9] loop above:
-- SUPER = switch, SUPER + SHIFT = send the window without following. Chords and
-- bare buttons coexist; Hyprland matches binds on (modmask, key). The buttons
-- land on workspaces 10 and 1, matching keys 0 and 1.

> **L714** before `describedBind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Focus next existing workspace")`

-- Scroll through existing workspaces with mainMod + scroll

> **L718** before `describedBind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Drag focused window", { mouse = true })`

-- Move/resize windows with mainMod + LMB/RMB and dragging

> **L771** before `describedBind(`

-- Laptop LCD brightness keys

## WINDOWS AND WORKSPACES

> **L823** before `hl.window_rule({`

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

> **L825** before `	name = "suppress-maximize-events",`

	-- Ignore maximize requests from all apps. You'll probably like this.

> **L833** before `	name = "fix-xwayland-drags",`

	-- Fix some dragging issues with XWayland

> **L900** before `hl.window_rule({`

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

> **L915** before `hl.window_rule({`

-- Hyprland-run windowrule

> **L934** before `hl.window_rule({`

-- Steam games are fullscreen on the main panel, workspace 10.
--
-- The monitor is keyed by NAME, not id. Monitor ids are enum-order and shift
-- across reboots (id 1 currently resolves to DP-2, a different panel), so a
-- numeric `monitor = 1` lands games on the wrong screen unpredictably.
--
-- `no_follow_mouse` opts the game out of `input.follow_mouse`. A fullscreen
-- game captures the pointer, so any mouse move Hyprland reads over the game
-- surface would hand focus away from it and the in-game cursor sticks where it
-- was captured. The opt-out only does anything while `follow_mouse` is non-zero,
-- so the two settings are coupled and must be read together.

> **L955** before `hl.window_rule({`

-- Sons Of The Forest is launched through gamescope (Steam launch option), so
-- the window Hyprland sees is gamescope's own toplevel -- class `gamescope`,
-- not `steam_app_<id>` -- and the rule above never matches it. Without this
-- the nested compositor lands as a normal tiled window on whatever workspace
-- is in view instead of fullscreen on the game panel.
--
-- Placement, fullscreen and `no_follow_mouse` mirror the rule above for the
-- same reasons; gamescope grabs the pointer itself, so Hyprland must not
-- reassign focus on a mouse move either.
--
-- `steam-game-fullscreen` is kept even though a gamescope game no longer
-- presents `steam_app_<id>`: games not launched through gamescope still do.

> **L977** before `hl.workspace_rule({`

-- Workspace 10 is the Steam-games workspace, and everything on it is
-- fullscreen, so a border and rounded corners draw over nothing but the game's
-- own pixels — visual noise, and a visible seam at the screen edges.
--
-- These keys are `no_border` / `no_rounding` on 0.56.2. `border = false` /
-- `rounding = false` is the 0.47-era spelling of the same thing and is now
-- silently dropped as an unknown field — third time this file got bitten by it
-- (window-rule `no_border`, `suppress_event` as a table, this). Neither the lua
-- binding nor the json printer complains; `configerrors` is the only report.
--
-- That spelling is workspace-rule-specific: on `hl.window_rule` `no_border` is
-- an unknown field and `border_size` is the equivalent.

> **L1009** before `hl.window_rule({`

-- Steam notification toasts (friend online, achievements) must survive a
-- fullscreen game on another workspace. Without this they silently vanish, and
-- the cause is compositor-side, not Steam: the toasts are XWayland windows of
-- class `steam` titled `notificationtoasts_<n>_desktop`, and Hyprland culls
-- every window that is not "allowed over fullscreen"
-- (Renderer.cpp, shouldRenderWindow). The policy that grants it
-- (WindowFullscreenPolicy.cpp, effectiveAllowedOverFullscreen) allows only four
-- cases: the fullscreen window itself, a *pinned* window, one explicitly
-- permitted, or one grouped with the fullscreen window. A toast is none of
-- those, so it gets dropped.
--
-- `pin` satisfies the policy in one move and also fixes the second half of the
-- bug: pinned windows render on every workspace, so a toast raised while
-- Steam itself sits on another workspace still appears over the game. That is
-- the whole reason these were invisible with the game on ws4 and Steam on 1-3.
--
-- `float` is not optional. Pinning is ignored for tiled windows, so without it
-- the pin silently does nothing.
--
-- `no_focus` because a notification must never steal focus from a running game;
-- the toast still draws and still takes clicks.
--
-- Tradeoff: a pinned window renders on every connected monitor, so the toast
-- appears in the corner of all three displays. That is the cost of not missing
-- it, and it is why this is scoped by title to the toasts alone rather than
-- pinning all of Steam.

> **L1036** before `hl.window_rule({`

-- Green frame while a window is fullscreen, so you can tell at a glance that
-- the app took the screen. #9ece6a is the Tokyo Night green that the active
-- border gradient replaced (general.col above), so it sits in the same palette
-- as #82aaff / #ff9e64 rather than arriving from nowhere.
--
-- Here `fullscreen = true` is a MATCH, not a rule property (contrast the
-- steam-game-fullscreen rule above, where it forces the state). Matches are
-- re-evaluated as the window's state changes, so the border reverts to the
-- blue->orange gradient on its own when the window leaves fullscreen.
--
-- border_size 4 rather than general's 2: on the 4K panel a 2px line at the
-- screen edge is too thin to register, and registering is the whole point.
-- Set it to 2 to match normal windows.
--
-- Workspace 10 games do not show this. The workspace rule above sets
-- no_border there, and a window with no border has no colour to paint.

