# run: soft-close-bind   status: done
request: bind SUPER+CTRL+C to a soft (graceful) close of the focused window — acceptance: bind registered live in hyprland.lua, sends a close *request* (not SIGKILL), SUPER+C kill untouched
base: n/a — `~/.config/hypr` is NOT a git repo. Delivery is a live-verified file edit, not a commit SHA.

| id | kind | status | complexity | model | session | worktree/branch | validated_commit | rounds | depends_on |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| soft-close-bind | implementation | validated | normal | session default | ses_f18321c05fferT7utxsyB6xTjd | live `~/.config/hypr` (no VCS) | none — verified via `hyprctl binds` | 1 | — |
| review | quality gate | validated | — | session default | ses_f1831776effeyvlegiCny2PNpA | — | no blocking, 3 nits | — | soft-close-bind |
| hypr-lua-api | research | superseded | normal | session default | ses_f18362888ffe5OozksnpOmF3gd | — | — | 0 | — |

## Decisions
- 2026-09-28: "soft close" = ONE graceful request. User chose A over hold-to-repeat and over a self-paced loop, and chose silence on failure. Settled in grilling, not revisited. Loop machinery (script, pin-address, bound, notify) is therefore NOT built. Revisit cost if wrong: add `{ repeating = true }` to the one bind line (hold-to-repeat) or ~6 lines of script (self-paced).
- 2026-09-28: keep `SUPER+C` = `hl.dsp.window.kill()`. User chose the two-key ladder over retargeting. The kill's commented-out `closeWindowBind:set_enabled(false)` is left in place.
- 2026-09-28: implementation lives in `hyprland.lua`, not the Quickshell bar. The bar has no `CustomShortcut`, no `IpcHandler`, no `Quickshell.Io` anywhere — an IPC layer would have been built from scratch to deliver a signal the user declined. Rejected: Quickshell-side bind.
- 2026-09-28: took review nit 1 (comment overclaimed the prompt), declined nits 2 and 3. Nit 2 (disambiguate the launcher description) is cosmetic — the launcher search already separates "close" from "kill". Nit 3 is a pre-existing misnomer on line 340 (`closeWindowBind` names a kill bind), out of scope.

## Findings & risks
- `~/.config/hypr` has no VCS. 7 `hyprland.lua.bak*` files are the only history. Same fragility that made the user approve `git init` for the quickshell config; not yet approved here. Backup at `/tmp/opencode/hyprland.lua.pre-softclose`.
- `hl.dsp.window.close()` exists in 0.56.2 — proven empirically, not from docs: a config that throws at load keeps the OLD config, so the bind simply would not appear in `hyprctl binds`. It appeared.
- Bind coexistence verified: modmask 64 (SUPER+C, kill), 65 (SUPER+SHIFT+C, tray), 68 (SUPER+CTRL+C, close). No collision.
- `luac -p` catches syntax only, NOT a nil `hl.dsp.*` field. The live reload + `hyprctl binds` is the only real check — gate the reload on `luac`, then prove with binds.
- The compositor SIGKILLs an app that ignores the close request, silently, because the user chose silence on failure. Noted in the bind's own comment so the next editor knows.
- The tokyonight tree has 7 uncommitted modified files (a timer pause-all change) predating this run. Untouched; the ledger commit staged explicit paths only.

## Verification evidence (measured live)
- `hyprctl binds`: `modmask: 68, key: C, description: Close focused window, dispatcher: __lua`.
- `SUPER+C` still `modmask: 64` / "Kill focused window", source line unchanged.
- `luac -p` → SYNTAX_OK; `hyprctl reload` → ok, twice (initial + comment reword).
- Diff vs backup: exactly 5 added lines. Only `hyprland.lua` has a new mtime; all `.bak*` untouched.

## Round log
- Round 1 review: 0 blocking, 3 nits. One comment reword dispatched back to the same implementer session, re-verified. 1 round total.

## Outstanding (not defects, user's call)
- `~/.config/hypr` still has no VCS.
- Line 340's local is named `closeWindowBind` but binds a SIGKILL. Pre-existing, now mildly confusing next to the real close bind.
- A `SUPER+CTRL+C` hold-to-repeat variant was available at zero extra cost and was declined. Revisit if a single request proves too weak in practice.
