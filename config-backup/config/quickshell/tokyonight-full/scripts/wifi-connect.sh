#!/bin/bash
# wifi-connect.sh — join, leave or forget a network, reporting the outcome.
#
#   wifi-connect.sh join <ssid> [password]
#   wifi-connect.sh leave <ssid>
#   wifi-connect.sh forget <ssid>
#
# Every action prints one JSON line: {"ok":true} on success,
# {"ok":false,"err":"<why>"} on failure. Settings.qml's result poll reads that
# line so the flyout can show the real verdict instead of a 4s guess. A call
# with no ssid prints usage to stderr and exits nonzero — that is the path the
# tests call, and it must not claim success.
#
# An open network needs no password, so the password argument is optional: it
# is passed on only when given, and NetworkManager prompts over the agent when
# the key is wrong or missing.
. "$(dirname "$0")/net-common.sh"

cmd=$1
ssid=$2
pass=$3

report() {
    # $1 = exit status, $2 = stderr text. The notice only has room for a short
    # line, so a long nmcli essay is cut to its first ~120 characters. cut -c
    # counts characters, not bytes, so a multibyte error stays valid UTF-8 —
    # ${2:0:120} under LC_ALL=C can split a rune and Qt would drop the whole
    # failure line rather than show a broken one.
    if [ "$1" -eq 0 ]; then
        printf '{"ok":true}\n'
    else
        printf '{"ok":false,"err":"%s"}\n' "$(jesc "$(printf '%s' "$2" | cut -c 1-120)")"
    fi
}

case "$cmd" in
    join)
        [ -z "$ssid" ] && { echo "usage: wifi-connect.sh join <ssid> [password]" >&2; exit 2; }
        if [ -n "$pass" ]; then
            err=$(nmcli --wait 20 device wifi connect "$ssid" password "$pass" 2>&1 >/dev/null)
            rc=$?
        else
            err=$(nmcli --wait 20 device wifi connect "$ssid" 2>&1 >/dev/null)
            rc=$?
        fi
        report "$rc" "$err"
        exit "$rc"
        ;;
    leave)
        [ -z "$ssid" ] && { echo "usage: wifi-connect.sh leave <ssid>" >&2; exit 2; }
        # Disconnect the adapter that is actually connected, not just the first
        # wifi device: on a multi-adapter laptop the old discovery could drop
        # the idle one and report failure while the network the user clicked
        # stayed up. The STATE column is that second fact checked.
        iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
                | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}')
        [ -z "$iface" ] && iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
                | awk -F: '$2=="wifi"{print $1; exit}')
        if [ -z "$iface" ]; then
            report 1 "no wifi device"
            exit 1
        fi
        # KDE disconnect keeps the saved profile — it only drops the link, so
        # there is no `connection down` and no deletion here.
        err=$(nmcli device disconnect "$iface" 2>&1 >/dev/null)
        rc=$?
        report "$rc" "$err"
        exit "$rc"
        ;;
    forget)
        [ -z "$ssid" ] && { echo "usage: wifi-connect.sh forget <ssid>" >&2; exit 2; }
        err=$(nmcli connection delete id "$ssid" 2>&1 >/dev/null)
        rc=$?
        report "$rc" "$err"
        exit "$rc"
        ;;
    *)    echo "usage: wifi-connect.sh <join|leave|forget> <ssid> [password]" >&2; exit 2 ;;
esac
