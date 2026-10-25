# Tokyonight full quickshell config

The live config. `quickshell -c "ZSW-Quickshell/Tokyonight full"` loads this directory.

## Edit here. Nowhere else.

This folder is part of the `ZSW-Dotfiles` repo, under `common/quickshell/` —
commit from `~/projects/ZSW-Dotfiles`.
`../Tokyonight lite/` is the default session bar and a separate config.

## Prove the reload

A failed reload leaves the OLD bar on screen, so the screen always looks fine.
Only the log tells you what happened.

    scripts/check-reload.sh

Run it right after saving a `.qml`. Exit 0 = loaded, exit 1 = it broke.
It prints only the last reload attempt, so it cannot be fooled by history.

Do **not** verify with `quickshell -c "ZSW-Quickshell/Tokyonight full" log | grep "Configuration
Loaded"`. That command replays the whole journal since the instance started —
it currently contains 25 reloads going back hours. Grepping it matches a stale
line and reports success for an edit that never loaded.

`touch` does not trigger a reload; it only raises `IN_ATTRIB`. Never conclude
the file watcher is dead from a bare `touch`.

## Other trees

- `~/.config/hypr/` — a separate Hyprland config, and it has **no git**.
- `../Tokyonight lite/` — the other bar variant in this repo.

## Conventions

- **New UI? Read `DESIGN.md` first.** Tokens (which colour for which job,
  radius, border, type scale), the rules this tree actually follows, and the
  QML traps that silently render nothing. Colours, fonts and radii come from
  `Tokyo.qml` by name — never a literal.
- QML files use **4 spaces**. `grep -cP '\t'` is 0 across all of them. Check
  the file before inserting anything.
- Timer ranges: `TimerState.maxMinutes` is the slider bound;
  `maxEntryMinutes` is the typed-entry clamp. They were once one variable,
  which made typing "45" silently start a 30:00 timer.
- `Repeater { model: <reassigned array> }` rebuilds every delegate on write, so
  any write from a pointer-move handler destroys the `MouseArea` holding the
  press. Drag holds state locally and writes **once, on release**.
- `Controls.TextField` swallows the press its own `contentItem` needs when a
  `MouseArea { anchors.fill: parent }` sits inside it. The overlay is
  deliberate — it triggers the host's layer-surface keyboard grab — so focus
  the field that was clicked rather than deleting the MouseArea.
- `z` orders siblings regardless of declaration order. Read the actual `z`, not
  the comment describing it.

## Deeper notes

`.opencode/orchestrator/learnings.md` — QML/Hyprland specifics worth reading
before non-trivial work here.