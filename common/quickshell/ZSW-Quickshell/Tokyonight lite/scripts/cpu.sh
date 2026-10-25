#!/bin/bash
# cpu.sh — overall CPU usage %, diff of /proc/stat between consecutive polls.
# One integer on stdout, no newline. Idle = idle + iowait.
set -euo pipefail

prev=/tmp/opencode/quickshell-cpu-prev
mkdir -p "$(dirname "$prev")"

read -r total idle < <(awk '/^cpu / { print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6 }' /proc/stat)

pct=0
if [ -r "$prev" ]; then
    read -r ptotal pidle < "$prev" 2>/dev/null || true
    if [[ "${ptotal:-}" =~ ^[0-9]+$ ]]; then
        dt=$((total - ptotal))
        di=$((idle - pidle))
        if [ "$dt" -gt 0 ]; then pct=$(( (dt - di) * 100 / dt )); fi
        [ "$pct" -lt 0 ] && pct=0
        [ "$pct" -gt 100 ] && pct=100
    fi
fi

printf '%s %s' "$total" "$idle" > "$prev"
printf '%s' "$pct"
