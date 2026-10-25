#!/bin/bash
# mem.sh — RAM used/total in GB for the quickshell bar.
# Used = MemTotal - MemAvailable. One line, pipe-delimited: used|total|pct.
set -euo pipefail

total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)

used_gb=$(awk -v t="$total" -v a="$avail" 'BEGIN { printf "%.1f", (t - a) / 1024 / 1024 }')
total_gb=$(awk -v t="$total" 'BEGIN { printf "%.1f", t / 1024 / 1024 }')
pct=$(awk -v t="$total" -v a="$avail" 'BEGIN { printf "%.0f", (t - a) * 100 / t }')

printf '%s|%s|%s' "$used_gb" "$total_gb" "$pct"
