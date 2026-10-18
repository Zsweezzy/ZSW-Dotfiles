#!/bin/bash
# hdr.sh — flip the Gigabyte M28U (DP-1) between HDR and SDR at runtime.
#
# `hyprctl keyword monitor ...` is dead on this box: the live Hyprland config is
# Lua, so keyword answers "keyword can't work with non-legacy parsers. Use
# eval". The runtime path is `hyprctl eval 'hl.monitor({...})'`, which prints
# `ok` on success, and that is what this script drives.
#
# There is no rule-removal API and every `hl.monitor` eval APPENDS a rule, so
# `on` is a no-op when the monitor already reports hdr (and `off` likewise when
# it already reports srgb) — otherwise repeated clicks would stack rules.
#
# Runtime only: nothing here survives a reboot or a Hyprland reload.
#
# usage: hdr.sh on|off|status
OUTPUT=DP-1
MODE=3840x2160@144.00
POSITION=1920x0
SCALE=2

# What the monitor says it is doing right now, or empty. Any read failure — no
# such output, no hyprctl, no jq — reads as not-hdr on purpose, so `status`
# degrades to `off` instead of erroring into its caller.
current_preset() {
    hyprctl -j monitors 2>/dev/null \
        | jq -r --arg output "$OUTPUT" \
            '.[] | select(.name == $output) | .colorManagementPreset' 2>/dev/null
}

status() {
    [ "$(current_preset)" = "hdr" ] && echo on || echo off
}

# Fail loudly: hyprctl eval prints `ok` and nothing else on success, so anything
# else is a real failure and must not look like the toggle worked.
run_eval() {
    local out
    if ! out=$(hyprctl eval "$1" 2>&1); then
        echo "hdr.sh: hyprctl eval failed: $out" >&2
        exit 1
    fi
    [ "$out" = "ok" ] || { echo "hdr.sh: hyprctl eval did not return ok: $out" >&2; exit 1; }
}

case "$1" in
    status) status ;;
    on)
        [ "$(status)" = "on" ] && exit 0
        run_eval "hl.monitor({ output = \"$OUTPUT\", mode = \"$MODE\", position = \"$POSITION\", scale = $SCALE, cm = \"hdr\", bitdepth = 10, sdrbrightness = 1.2, sdrsaturation = 1.0 })"
        ;;
    off)
        [ "$(status)" = "off" ] && exit 0
        run_eval "hl.monitor({ output = \"$OUTPUT\", mode = \"$MODE\", position = \"$POSITION\", scale = $SCALE, cm = \"srgb\", bitdepth = 8 })"
        ;;
    *) echo "usage: hdr.sh on|off|status" >&2; exit 2 ;;
esac
