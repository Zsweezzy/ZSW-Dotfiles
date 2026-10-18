#!/bin/bash
# test-hdr.sh — hdr.sh's parsing and its no-op guard, without a real monitor.
#
# What is worth testing here is not the Hyprland call but the two things that
# bite on a live box:
#
#   * `status` must read DP-1's `colorManagementPreset`, not some other output's
#     (the bar lists three monitors), and must degrade to `off` when the output
#     is missing — the tile lights from this word alone.
#   * each `hl.monitor` eval APPENDS a rule and there is no remove API, so `on`
#     while already hdr must NOT eval again. The stub logs every call, so a
#     stray append is visible even though the screen would look fine.
#
# hyprctl is stubbed on PATH: `-j monitors` answers canned JSON, `eval` answers
# `ok` (or whatever HYPRCTL_EVAL_OUT is set to). Run from anywhere:
# cd "$(dirname "$0")/.." first.
cd "$(dirname "$0")/.." || exit 1
fail=0
ok()  { printf '  ok   %s\n' "$1" >&2; }
bad() { printf '  FAIL %s\n' "$1" >&2; fail=1; }

t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

cat > "$t/hyprctl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$HYPRCTL_LOG"
case "$1" in
    -j)   printf '%s' "$HYPRCTL_MONITORS" ;;
    eval) printf '%s' "${HYPRCTL_EVAL_OUT:-ok}" ;;
esac
exit 0
STUB
chmod +x "$t/hyprctl"
export PATH="$t:$PATH"
export HYPRCTL_LOG="$t/calls"

# status reads the preset, and only DP-1's
export HYPRCTL_MONITORS='[{"name":"DP-2","colorManagementPreset":"hdr"},{"name":"DP-1","colorManagementPreset":"srgb"}]'
got=$(scripts/hdr.sh status)
[ "$got" = "off" ] && ok "status: DP-1 srgb reads off" || bad "status: got '$got', want off"

export HYPRCTL_MONITORS='[{"name":"DP-1","colorManagementPreset":"hdr"},{"name":"DP-2","colorManagementPreset":"srgb"}]'
got=$(scripts/hdr.sh status)
[ "$got" = "on" ] && ok "status: DP-1 hdr reads on" || bad "status: got '$got', want on"

# a missing output is off, not an error
export HYPRCTL_MONITORS='[{"name":"DP-2","colorManagementPreset":"hdr"}]'
got=$(scripts/hdr.sh status)
[ "$got" = "off" ] && ok "status: no DP-1 reads off" || bad "status: got '$got', want off"

# unreadable monitors data is off too
export HYPRCTL_MONITORS='not json'
got=$(scripts/hdr.sh status)
[ "$got" = "off" ] && ok "status: unparseable monitors reads off" || bad "status: got '$got', want off"

# `on` from srgb evals the HDR rule (10-bit, cm=hdr)
export HYPRCTL_MONITORS='[{"name":"DP-1","colorManagementPreset":"srgb"}]'
: > "$HYPRCTL_LOG"
scripts/hdr.sh on >/dev/null 2>&1
if grep -q 'eval hl.monitor' "$HYPRCTL_LOG" \
   && grep -q 'cm = "hdr"' "$HYPRCTL_LOG" \
   && grep -q 'bitdepth = 10' "$HYPRCTL_LOG"; then
    ok "on: evals hl.monitor with cm=hdr, bitdepth=10"
else
    bad "on: eval was wrong: $(cat "$HYPRCTL_LOG" | tr '\n' '|')"
fi

# `off` from hdr evals the SDR rule (8-bit, cm=srgb)
export HYPRCTL_MONITORS='[{"name":"DP-1","colorManagementPreset":"hdr"}]'
: > "$HYPRCTL_LOG"
scripts/hdr.sh off >/dev/null 2>&1
if grep -q 'eval hl.monitor' "$HYPRCTL_LOG" \
   && grep -q 'cm = "srgb"' "$HYPRCTL_LOG" \
   && grep -q 'bitdepth = 8' "$HYPRCTL_LOG"; then
    ok "off: evals hl.monitor with cm=srgb, bitdepth=8"
else
    bad "off: eval was wrong: $(cat "$HYPRCTL_LOG" | tr '\n' '|')"
fi

# No-op guards: already on / already off must not append another rule
export HYPRCTL_MONITORS='[{"name":"DP-1","colorManagementPreset":"hdr"}]'
: > "$HYPRCTL_LOG"
scripts/hdr.sh on >/dev/null 2>&1
grep -q 'eval' "$HYPRCTL_LOG" && bad "on: appended a rule while already hdr" \
                               || ok "on: already hdr is a no-op (no eval)"

export HYPRCTL_MONITORS='[{"name":"DP-1","colorManagementPreset":"srgb"}]'
: > "$HYPRCTL_LOG"
scripts/hdr.sh off >/dev/null 2>&1
grep -q 'eval' "$HYPRCTL_LOG" && bad "off: appended a rule while already srgb" \
                               || ok "off: already off is a no-op (no eval)"

# A failed eval must be loud, not silently counted as a successful toggle
export HYPRCTL_MONITORS='[{"name":"DP-1","colorManagementPreset":"srgb"}]'
HYPRCTL_EVAL_OUT='error: no such output' scripts/hdr.sh on >/dev/null 2>&1
rc=$?
[ "$rc" -ne 0 ] && ok "on: a failed eval exits non-zero" \
                || bad "on: a failed eval exited 0"

# Argument handling
scripts/hdr.sh sideways >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && ok "rejects a bad verb with exit 2" || bad "bad verb exit $rc, want 2"
scripts/hdr.sh >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && ok "rejects a missing verb with exit 2" || bad "missing verb exit $rc, want 2"

[ $fail -eq 0 ] && echo "hdr tests passed" || { echo "hdr tests FAILED"; exit 1; }
