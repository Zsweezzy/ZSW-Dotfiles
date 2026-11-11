#!/usr/bin/env bash
# What the live shell costs right now: RSS and CPU time, one line.
#
# Run it before and after a change. There is no benchmark harness here and
# there does not need to be: the bar is one process, and the numbers that move
# are memory and accumulated CPU. A committed baseline is more useful than a
# micro-benchmark nobody reruns.
#
# Usage: scripts/perf-baseline.sh [label]
set -o pipefail

pid=$(pgrep -x quickshell | head -1)
if [ -z "$pid" ]; then
    echo "perf-baseline: no quickshell is running" >&2
    exit 1
fi

label=${1:-live}
# Field 22 (starttime) + utime/stime from /proc/pid/stat, plus VmRSS from
# status. ps prints the same thing, but the raw files are stable across
# procps versions.
read -r _ _ _ _ _ _ _ _ _ _ _ _ _ utime stime _ < <(awk '{ n = index($0, ")"); print substr($0, n + 2) }' "/proc/$pid/stat")
rss=$(awk '/VmRSS/ { print $2 }' "/proc/$pid/status")
ticks=$(getconf CLK_TCK)
cpu=$(awk -v u="$utime" -v s="$stime" -v t="$ticks" 'BEGIN { printf "%.2f", (u + s) / t }')

printf '%s pid=%s rss=%sMB cpu=%ss\n' "$label" "$pid" "$((rss / 1024))" "$cpu"
