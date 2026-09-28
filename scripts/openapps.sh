#!/bin/bash
# openapps.sh — taskbar cluster source: one pink nerd-font glyph per open
# application (deduped by class, first-seen order), with the window title for
# per-icon tooltips. Outputs JSON (return-type: json):
#   { "apps": [ {class, glyph, title}, ... ] }
# The pill renders each app as its own clickable cell (left-click focuses it).

# Emit the REAL glyph characters (not "\uf269" escape strings) so the JSON
# carries the actual PUA code points and the pill renders them as glyphs.
glyphs() {
    case "$1" in
        *firefox*|*chromium*|*brave*|*zen*|*webkit*) printf '\uf269' ;;   # browser
        *kitty*|*alacritty*|*wezterm*|*foot*|*konsole*|*ghostty*|*urxvt*|*xterm*) printf '\uf120' ;;  # terminal
        *kate*|*kwrite*|*sublime*|*code*|*vim*|*nvim*|*emacs*|*zed*) printf '\uf044' ;;  # editor
        *dolphin*|*nautilus*|*thunar*|*pcmanfm*|*nemo*) printf '\uf07b' ;;  # file manager
        *) printf '\uf0c8' ;;  # generic app
    esac
}

clients=$(hyprctl clients -j 2>/dev/null)
[ -z "$clients" ] && exit 0

# unique classes (first-seen order) with the first window's title. Windows
# parked on Hyprland's hidden special:tray workspace are tray background apps —
# they belong to the tray section of the merged cluster, not here.
apps=$(jq -r '.[] | select(.mapped == true and .workspace.name != "special:tray" and .class != null and .class != "") |
               [.class, (.title // "")] | @tsv' <<<"$clients" | awk '!seen[$1]++')
[ -z "$apps" ] && exit 0

# class<TAB>glyph<TAB>title per app, then let jq build + escape the JSON array.
printf '%s\n' "$apps" | while IFS=$'\t' read -r cls title; do
    printf '%s\t%s\t%s\n' "$cls" "$(glyphs "$cls")" "$title"
done | jq -cnR '[inputs | select(length > 0) | split("\t") | {class: .[0], glyph: .[1], title: .[2]}] | {apps: .}'