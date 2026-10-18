#!/usr/bin/env python3
"""
set-steam-launch-options.py - write uniform Proton launch options into
Steam's localconfig.vdf for every installed game that lacks them.

Reproduces exactly what was done on 2026-10-14 (see ../09-launch-options-applied.md).

What it does
------------
- Finds every installed Steam game (appmanifest_*.acf in all libraries).
- Filters out non-games and anti-cheat titles.
- For each remaining game, if its LaunchOptions key is missing or empty, writes
  the uniform string. Non-empty values are never overwritten.
- Verifies the edit by comparing the full (path -> value) multiset before/after
  AND by re-parsing the written file. Writes only if the verification passes.
- Takes a timestamped backup next to localconfig.vdf.

Usage
-----
    python3 set-steam-launch-options.py --dry-run      # show what would change
    python3 set-steam-launch-options.py                # apply

Steam MUST be closed, or Steam will overwrite the file on exit.
"""

import argparse
import glob
import io
import os
import re
import shutil
import subprocess
import sys
import time
from collections import Counter

LOCALCONFIG = ("/home/maxii/.local/share/Steam/userdata/"
               "1145198416/config/localconfig.vdf")
LIBRARY_GLOBS = [
    "/home/maxii/.local/share/Steam/steamapps/appmanifest_*.acf",
    "/home/maxii/games/SteamLibrary/steamapps/appmanifest_*.acf",
]
UNIFORM = ("ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 "
           "PROTON_DXVK_LOWLATENCY=1 gamemoderun %command%")

# Titles that are tools/runtimes, not games.
SKIP = re.compile(
    r"proton|steam linux runtime|steamworks|dedicated server|OBS Studio|"
    r"ShareX|Soundpad|Borderless Gaming|Wallpaper Engine|"
    r"Sim Racing Telemetry|BattlEye", re.I)

# Anti-cheat games: excluded from gamemoderun (LD_PRELOAD injection).
ANTICHEAT = {"1245620", "2290180", "2698940"}


def tokenize(s):
    """Yield ('{','{',st,en) / ('}','}',st,en) / ('s',value,st,en)."""
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c in " \t\r\n":
            i += 1
            continue
        if c == "{":
            yield ("{", "{", i, i + 1); i += 1; continue
        if c == "}":
            yield ("}", "}", i, i + 1); i += 1; continue
        if c == '"':
            st = i; i += 1; buf = []
            while i < n:
                if s[i] == "\\" and i + 1 < n:
                    buf.append(s[i + 1]); i += 2; continue
                if s[i] == '"':
                    i += 1; break
                buf.append(s[i]); i += 1
            yield ("s", "".join(buf), st, i); continue
        j = i
        while i < n and s[i] not in ' \t\r\n{}"':
            i += 1
        yield ("s", s[j:i], j, i)


def pairs(s):
    """All leaf (slash/joined/path, value) pairs, sorted - the audit fingerprint."""
    out, stack, pending = [], [], None
    for kind, val, st, en in tokenize(s):
        if kind == "{":
            stack.append(pending if pending is not None else "?"); pending = None
        elif kind == "}":
            stack.pop(); pending = None
        else:
            if pending is None:
                pending = val
            else:
                out.append(("/".join(stack + [pending]), val)); pending = None
    return sorted(out)


def analyse(s):
    """Return (apps_content_offset, {appid: {open, close, has_lo, lo_value}})."""
    apps_off = apps_depth = None
    blocks, stack = {}, []
    pending = cur = cur_var = None
    for kind, val, st, en in tokenize(s):
        if kind == "{":
            key = pending; pending = None
            top = stack[-4:] if len(stack) >= 4 else []
            stack.append(key)
            if key == "apps" and top == ["UserLocalConfigStore", "Software",
                                         "Valve", "Steam"]:
                apps_off, apps_depth = en, len(stack)
            elif apps_depth is not None and len(stack) == apps_depth + 1:
                cur, cur_var = key, None
                blocks[key] = {"open": en}
        elif kind == "}":
            if apps_depth is not None and cur is not None \
                    and len(stack) == apps_depth + 1:
                blocks[cur]["close"] = st
                blocks[cur]["has_lo"] = cur_var is not None
                blocks[cur]["lo_value"] = cur_var
                cur = cur_var = None
            stack.pop(); pending = None
        else:
            if pending is None:
                pending = val
            else:
                if cur is not None and pending == "LaunchOptions":
                    cur_var = (st, en)
                pending = None
    return apps_off, blocks


def installed_games():
    found = {}
    for pattern in LIBRARY_GLOBS:
        for path in glob.glob(pattern):
            text = io.open(path, encoding="utf-8", errors="replace").read()
            data = dict(re.findall(r'"(\w+)"\s+"([^"]*)"', text))
            if data.get("appid"):
                found[data["appid"]] = data.get("name", "")
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--localconfig", default=LOCALCONFIG)
    args = ap.parse_args()

    if subprocess.run(["pgrep", "-x", "steam"],
                      capture_output=True).returncode == 0:
        sys.exit("ABORT: Steam is running. Close it first.")

    installed = installed_games()
    targets = {a: n for a, n in installed.items()
               if n and not SKIP.search(n) and a not in ANTICHEAT}
    print("installed entries: %d | game targets: %d" % (len(installed), len(targets)))

    src = io.open(args.localconfig, encoding="utf-8").read()
    before = Counter(pairs(src))
    apps_off, blocks = analyse(src)
    if apps_off is None:
        sys.exit("ABORT: could not locate the apps block")

    # learn the exact indentation from an existing LaunchOptions line
    indent2 = sep = None
    for appid, block in blocks.items():
        if block.get("has_lo") and block.get("lo_value") and "close" in block:
            region = src[block["open"]:block["close"]]
            m = re.search(r'\n([ \t]*)"LaunchOptions"([ \t]*)"', region)
            if m:
                indent2, sep = m.group(1), m.group(2)
                open_off = block["open"]
                line_start = src.rfind("\n", 0, open_off - 1) + 1
                indent1 = src[line_start:open_off - 1]
                break
    if indent2 is None:
        sys.exit("ABORT: no existing LaunchOptions to learn formatting from")

    edits, skipped = [], []
    for appid in targets:
        block = blocks.get(appid)
        if block and block.get("has_lo") and block.get("lo_value"):
            st, en = block["lo_value"]
            value = src[st + 1:en - 1] if src[st] == '"' else src[st:en]
            if value.strip():
                skipped.append((appid, targets[appid], value))
                continue
            edits.append(("replace", st, en, '"%s"' % UNIFORM, appid))
        elif block and "close" in block:
            edits.append(("insert", block["open"], block["open"],
                          '\n%s"LaunchOptions"%s"%s"'
                          % (indent2, sep, UNIFORM), appid))
        else:
            edits.append(("newblock", apps_off, apps_off,
                          '\n%s"%s"\n%s{\n%s"LaunchOptions"%s"%s"\n%s}'
                          % (indent1, appid, indent1, indent2, sep, UNIFORM,
                             indent1), appid))

    new = src
    for _, start, stop, text, _ in sorted(edits, key=lambda e: -e[1]):
        new = new[:start] + text + new[stop:]

    after = Counter(pairs(new))
    added, removed = after - before, before - after
    edited = [e[4] for e in edits]
    expected_add = Counter({
        ("UserLocalConfigStore/Software/Valve/Steam/apps/%s/LaunchOptions" % a,
         UNIFORM): 1 for a in edited})
    expected_rem = Counter({
        ("UserLocalConfigStore/Software/Valve/Steam/apps/%s/LaunchOptions" % a,
         ""): 1 for _, _, _, _, a in edits if _ == "replace"})

    ok = added == expected_add and removed == expected_rem
    print("edits: replace=%d insert=%d newblock=%d | skipped=%d"
          % (sum(1 for e in edits if e[0] == "replace"),
             sum(1 for e in edits if e[0] == "insert"),
             sum(1 for e in edits if e[0] == "newblock"),
             len(skipped)))
    print("pairs added=%d (expected %d) removed=%d (expected %d)"
          % (sum(added.values()), sum(expected_add.values()),
             len(removed), len(expected_rem)))
    print("VERIFY:", "PASS" if ok else "FAIL")
    if not ok:
        sys.exit("verification failed - nothing written")
    if args.dry_run:
        print("dry-run: no changes written")
        return

    backup = "%s.bak-%s-launchopts" % (args.localconfig,
                                       time.strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(args.localconfig, backup)
    io.open(args.localconfig, "w", encoding="utf-8").write(new)
    disk = io.open(args.localconfig, encoding="utf-8").read()
    print("WROTE %s (bytes %d -> %d, reread identical: %s)"
          % (args.localconfig, len(src), len(disk), disk == new))
    print("backup: %s" % backup)


if __name__ == "__main__":
    main()
