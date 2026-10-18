#!/bin/bash
# waybar audio controls — PipeWire/WirePlumber via wpctl, menus in rofi.
#   output (left click)  : pick the default output device
#   input  (right click) : pick the default input device
#   apps   (middle click): adjust the volume of a single application
set -eu

action="${1:-output}"

menu() { rofi -dmenu -i -p "$1" -no-custom; }

# Extract node lines of a `wpctl status` section, e.g. "47. Built-in Audio Analog Stereo [vol: 0.50]"
node_lines() { # $1 section start, $2 section end
  wpctl status 2>/dev/null | sed -n "/$1/,/$2/p" \
    | grep -oE '[0-9]+\. .*' | sed -E 's/ \[(vol|muted).*//'
}

node_id()   { echo "$1" | sed -E 's/^ *([0-9]+)\..*/\1/'; }
node_name() { echo "$1" | sed -E 's/^ *[0-9]+\. *//'; }

case "$action" in
  output)
    sel=$(node_lines "Sinks:" "Sources:" | menu "Output device")
    [ -n "$sel" ] && wpctl set-default "$(node_id "$sel")"
    ;;
  input)
    sel=$(node_lines "Sources:" "Sink inputs:" | menu "Input device")
    [ -n "$sel" ] && wpctl set-default "$(node_id "$sel")"
    ;;
  apps)
    sel=$(node_lines "Sink inputs:" "Source outputs:" | menu "Application")
    [ -z "$sel" ] && exit 0
    id=$(node_id "$sel")
    act=$(printf 'Raise volume +5%%\nLower volume -5%%\nToggle mute\nSet 100%%\nSet 0%%' \
          | menu "Volume for: $(node_name "$sel")")
    case "$act" in
      "Raise volume +5%") wpctl set-volume "$id" 5%+ ;;
      "Lower volume -5%") wpctl set-volume "$id" 5%- ;;
      "Toggle mute")      wpctl set-mute "$id" toggle ;;
      "Set 100%")         wpctl set-volume "$id" 100% ;;
      "Set 0%")           wpctl set-volume "$id" 0% ;;
    esac
    ;;
esac