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
    # line, so a long nmcli essay is cut to its first ~120 chars.
    if [ "$1" -eq 0 ]; then
        printf '{"ok":true}\n'
    else
        printf '{"ok":false,"err":"%s"}\n' "$(jesc "${2:0:120}")"
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
        ;;
    leave)
        [ -z "$ssid" ] && { echo "usage: wifi-connect.sh leave <ssid>" >&2; exit 2; }
        # The wifi device is not always wlan0: the same discovery wifi-list.sh
        # uses is the only wording that stays right on a machine where it is not.
        iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
                | awk -F: '$2=="wifi"{print $1; exit}')
        # KDE disconnect keeps the saved profile — it only drops the link, so
        # there is no `connection down` and no deletion here.
        err=$(nmcli device disconnect "$iface" 2>&1 >/dev/null)
        rc=$?
        report "$rc" "$err"
        ;;
    forget)
        [ -z "$ssid" ] && { echo "usage: wifi-connect.sh forget <ssid>" >&2; exit 2; }
        err=$(nmcli connection delete id "$ssid" 2>&1 >/dev/null)
        rc=$?
        report "$rc" "$err"
        ;;
    *)    echo "usage: wifi-connect.sh <join|leave|forget> <ssid> [password]" >&2; exit 2 ;;
esac