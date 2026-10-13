#!/bin/bash
# bt-scan.sh — discover nearby bluetooth devices, as one JSON line.
#
# Pairing is a separate step (bt-dev.sh), because a pair needs a confirmation
# on the other device's screen and so can take longer than one poll cycle.
. "$(dirname "$0")/net-common.sh"

secs=${1:-8}
# A scan holds the radio for its whole window, so refuse a typo like `abc`
# before spawning anything rather than scanning with a bogus timeout.
case "$secs" in
    ''|*[!0-9]*|0) echo "usage: bt-scan.sh [seconds>0]" >&2; exit 2 ;;
esac
bluetoothctl power on >/dev/null 2>&1

# ONLY the devices THIS scan reported. bluez's own `devices` list is a cache of
# everything it has ever seen, so an earlier sighting that is not here now would
# be listed as freshly found. [DEL] lines are devices that just went away.
macs=$(bluetoothctl --timeout "$secs" scan on 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk '$2 == "Device" && $1 != "[DEL]" {print $3}' \
    | sort -u)

devs=""
while read -r mac; do
    [ -n "$mac" ] || continue
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    paired=false
    [ "$(printf '%s' "$info" | awk -F': ' '/Paired:/{print $2}')" = "yes" ] && paired=true
    name=$(printf '%s' "$info" | sed -n 's/^\(Alias\|Name\): //p' | head -1)
    [ -z "$name" ] && name=$mac
    icon=$(printf '%s' "$info" | sed -n 's/^Icon: //p' | head -1)
    [ -n "$devs" ] && devs="$devs,"
    devs="$devs{\"mac\":\"$(jesc "$mac")\",\"name\":\"$(jesc "$name")\",\"paired\":$paired,\"icon\":\"$(jesc "$icon")\"}"
done <<< "$macs"

printf '{"devices":[%s]}\n' "$devs"
