-- Comments extracted to hyprland.comments.md (2026-10-20) -- read it for context.
------------------
---- MONITORS ----
------------------
hl.monitor({
	output = "HDMI-A-1",
	mode = "1920x1080@100.08",
	position = "0x0",
	scale = 1,
})
hl.monitor({
	output = "DP-1",
	mode = "3840x2160@144.00",
	position = "1920x0",
	scale = 2,
})
hl.monitor({
	output = "DP-2",
	mode = "1920x1080@240.00",
	position = "3840x0",
	scale = 1,
})

--------------------------
---- PROGRAMS AND VARS ----
--------------------------
local terminal = "kitty"
local fileManager = "dolphin"
local mainMod = "SUPER"
local function describedBind(key, dispatcher, description, options)
	options = options or {}
	options.description = description
	return hl.bind(key, dispatcher, options)
end

-------------------------
---- ENVIRONMENT VARS ----
-------------------------
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "22")
hl.env("HYPR_LAUNCHER_TERMINAL", terminal)
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("GTK_USE_PORTAL", "1")
hl.config({
	xwayland = {
		force_zero_scaling = true,
	},
})

-------------------
---- LOOK AND FEEL ----
-------------------
hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 6,
		border_size = 2,
		col = {
			active_border = { colors = { "rgba(82aaffee)", "rgba(ff9e64ee)" }, angle = 45 },
			inactive_border = "rgba(2f334daa)",
		},
		layout = "dwindle",
	},
	decoration = {
		rounding = 10,
		shadow = {
			enabled = true,
			range = 12,
			render_power = 3,
			offset = { 0, 4 },
			color = 0xee16161e,
		},
		blur = {
			size = 3,
		},
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
	},
})
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })
hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3.0, bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 2.8, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.4, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.0, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.0, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.9, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 0.6, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 0.6, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.6, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.6, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.6, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.2, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 0.8, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.2, bezier = "almostLinear", style = "fade" })
hl.animation({
	leaf = "specialWorkspaceIn",
	enabled = true,
	speed = 2.6,
	bezier = "easeOutQuint",
	style = "slidevert bottom",
})
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.0, bezier = "linear", style = "slidevert top" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "quick" })
hl.config({
	dwindle = {
		preserve_split = true,
	},
})

---------------
---- INPUT ----
---------------
hl.config({
	input = {
		kb_layout = "de",
		sensitivity = -0.3,
		accel_profile = "flat",
	},
})

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("quickshell -c tokyonight")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("/home/maxii/.local/bin/hypr-shortcut-launcher --background")
	hl.exec_cmd("/home/maxii/.local/bin/neru launch")
	hl.exec_cmd("hyprpm reload")
	hl.exec_cmd("mkdir -p \"${XDG_RUNTIME_DIR:-$HOME/.cache}\"; flock -n \"${XDG_RUNTIME_DIR:-$HOME/.cache}/hypr-session-autosave.lock\" /home/maxii/.local/bin/hypr-session autosave-loop")
	hl.exec_cmd("sleep 2 && hyprctl reload")
end)
hl.on("hyprland.shutdown", function()
	hl.exec_cmd("/home/maxii/.local/bin/hypr-session save")
end)

--------------------
---- KEYBINDINGS ----
--------------------
---- APPS AND SCRIPTS ----
describedBind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), "Open terminal")
describedBind(
	mainMod .. " + K",
	hl.dsp.exec_cmd("/home/maxii/.local/bin/hypr-shortcut-launcher"),
	"Open shortcuts and apps launcher"
)
describedBind(
	mainMod .. " + R",
	hl.dsp.exec_cmd("rofi -monitor DP-1 -show drun"),
	"Open application launcher"
)
describedBind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), "Open file manager")
describedBind(mainMod .. " + W", hl.dsp.exec_cmd("firefox"), "Open Firefox")
describedBind(mainMod .. " + T", hl.dsp.exec_cmd("steam"), "Open Steam")
describedBind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("spotify"), "Open Spotify")
describedBind(mainMod .. " + I", hl.dsp.exec_cmd(terminal .. " -e hypr-settings"), "Open settings")
describedBind(
	mainMod .. " + V",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/clipboard.sh"),
	"Open clipboard history"
)
describedBind(mainMod .. " + F10", hl.dsp.exec_cmd("shadowclip"), "Open shadowclip")
describedBind(
	mainMod .. " + D",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/duplicate-window.sh"),
	"Duplicate focused window"
)
describedBind(
	mainMod .. " + CTRL + S",
	hl.dsp.exec_cmd("/home/maxii/.local/bin/hypr-session save --notify"),
	"Save session snapshot"
)
describedBind(
	mainMod .. " + CTRL + R",
	hl.dsp.exec_cmd("/home/maxii/.local/bin/hypr-session restore --notify"),
	"Restore session snapshot"
)
describedBind(mainMod .. " + U", hl.dsp.exec_cmd("konsole -e sh -c \"sudo cachy-update; echo; echo 'Press Enter to close...'; read\""), "CachyOS system update")
describedBind(mainMod .. " + M", hl.dsp.exit(), "Log out or exit Hyprland")

---- WINDOWS ----
describedBind(mainMod .. " + Tab", function()
	if hl.plugin and hl.plugin.hymission then
		hl.plugin.hymission.toggle()
	end
end, "Toggle workspace overview")
describedBind(
	"ALT + tab",
	function()
		if hl.plugin and hl.plugin.hymission then
			hl.plugin.hymission.toggle()
		end
	end,
	"Toggle workspace overview",
	{ allow_input_capture = true }
)
describedBind(mainMod .. " + C", hl.dsp.window.kill(), "Kill focused window")
describedBind(mainMod .. " + SHIFT + C", hl.dsp.window.close(), "Close focused window")
describedBind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }), "Toggle focused window floating")
describedBind(mainMod .. " + P", hl.dsp.window.pseudo(), "Toggle pseudo-terminal")
describedBind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize focused window")
describedBind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(), "Toggle fullscreen")
describedBind(mainMod .. " + J", hl.dsp.layout("togglesplit"), "Toggle split layout")
describedBind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), "Focus window left")
describedBind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), "Focus window right")
describedBind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), "Focus window up")
describedBind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), "Focus window down")
describedBind(
	mainMod .. " + SHIFT + left",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/move-fullscreen.sh left"),
	"Move focused window left"
)
describedBind(
	mainMod .. " + SHIFT + right",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/move-fullscreen.sh right"),
	"Move focused window right"
)
describedBind(
	mainMod .. " + SHIFT + up",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/move-fullscreen.sh up"),
	"Move focused window up"
)
describedBind(
	mainMod .. " + SHIFT + down",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/move-fullscreen.sh down"),
	"Move focused window down"
)
describedBind(mainMod .. " + ALT + left", hl.dsp.window.swap({ direction = "left" }), "Swap focused window left")
describedBind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }), "Swap focused window right")
describedBind(mainMod .. " + ALT + up", hl.dsp.window.swap({ direction = "up" }), "Swap focused window up")
describedBind(mainMod .. " + ALT + down", hl.dsp.window.swap({ direction = "down" }), "Swap focused window down")

---- WORKSPACES ----
for i = 1, 10 do
	local key = i % 10
	describedBind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), "Focus workspace " .. i)
	describedBind(
		mainMod .. " + SHIFT + " .. key,
		hl.dsp.window.move({ workspace = i, follow = false }),
		"Send focused window to workspace " .. i
	)
	describedBind(
		mainMod .. " + CTRL + " .. key,
		hl.dsp.window.move({ workspace = i }),
		"Move focused window to workspace " .. i .. " (follow)"
	)
end
describedBind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = 10 }), "Focus workspace 10 (mouse)")
describedBind(mainMod .. " + mouse:276", hl.dsp.focus({ workspace = 1 }), "Focus workspace 1 (mouse)")
describedBind(
	mainMod .. " + SHIFT + mouse:275",
	hl.dsp.window.move({ workspace = 10, follow = false }),
	"Send focused window to workspace 10 (mouse)"
)
describedBind(
	mainMod .. " + SHIFT + mouse:276",
	hl.dsp.window.move({ workspace = 1, follow = false }),
	"Send focused window to workspace 1 (mouse)"
)
describedBind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Focus next existing workspace")
describedBind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Focus previous existing workspace")
describedBind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"), "Toggle magic workspace")
describedBind(
	mainMod .. " + SHIFT + S",
	hl.dsp.window.move({ workspace = "special:magic" }),
	"Move focused window to magic workspace"
)

---- SCREENSHOTS ----
describedBind(
	"print",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/screenshot-monitor.sh"),
	"Take screenshot of active monitor"
)
describedBind(
	"SHIFT + print",
	hl.dsp.exec_cmd("/home/maxii/.config/hypr/scripts/screenshot-region.sh"),
	"Take screenshot of selected region"
)
describedBind(
	mainMod .. " + print",
	hl.dsp.exec_cmd(
		'latest=$(ls -t /home/maxii/Pictures/Screenshots/*.png 2>/dev/null | head -1); [ -n "$latest" ] && flatpak run com.interversehq.qView "$latest" || notify-send -u critical -a screenshot \'No screenshots yet\''
	),
	"Open latest screenshot"
)

---- MEDIA AND HARDWARE KEYS ----
describedBind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
	"Increase screen brightness",
	{ locked = true, repeating = true }
)
describedBind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
	"Decrease screen brightness",
	{ locked = true, repeating = true }
)

---- MOUSE ----
describedBind(mainMod .. " + mouse:272", hl.dsp.window.drag(), "Drag focused window", { mouse = true })
describedBind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Resize focused window", { mouse = true })
describedBind(
	"ALT + SHIFT + tab",
	hl.dsp.release_input_capture(),
	"Free the mouse cursor from a window that captured it",
	{ allow_input_capture = true }
)

-------------------------------
---- WINDOWS AND WORKSPACES ----
-------------------------------
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})
hl.window_rule({
	name = "steam-game-fullscreen",
	match = { class = "^steam_app_\\d+$" },
	fullscreen = true,
	monitor = "DP-1",
	workspace = 10,
	no_follow_mouse = true,
})
hl.window_rule({
	name = "gamescope-fullscreen",
	match = { class = "^gamescope$" },
	fullscreen = true,
	monitor = "DP-1",
	workspace = 10,
	no_follow_mouse = true,
})
hl.workspace_rule({
	workspace = "10",
	no_border = true,
	no_rounding = true,
})
hl.window_rule({
	name = "steam-toast-over-fullscreen",
	match = {
		class = "^steam$",
		title = "^notificationtoasts_.*_desktop$",
	},
	float = true,
	pin = true,
	no_focus = true,
})
hl.window_rule({
	name = "fullscreen-border-green",
	match = { fullscreen = true },
	border_color = "rgb(9ece6a)",
	border_size = 4,
})
