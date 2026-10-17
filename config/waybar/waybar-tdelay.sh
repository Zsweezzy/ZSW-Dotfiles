#!/bin/sh
# waybar-tdelay.sh — launch waybar with the 50 ms tooltip-delay shim.
# GTK3 hardcodes a 500 ms tooltip hover delay and ignores its old
# `gtk-tooltip-timeout` setting (deprecated 3.10); this preloads a small
# interposer that pulls the tooltip timer forward (see tooltip-delay.c).
export LD_PRELOAD="/home/maxii/.config/waybar/libtooltip-delay.so${LD_PRELOAD:+:$LD_PRELOAD}"
exec /usr/bin/waybar "$@"