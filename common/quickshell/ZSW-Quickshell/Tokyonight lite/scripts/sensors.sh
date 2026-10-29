#!/usr/bin/env sh
# CPU/GPU temperature and fan speed, one line: "cpu|gpu|fan".
#
# hwmon indices are not stable across boots, so the chip name is the lookup:
# k10temp is the CPU, amdgpu the GPU (the card that has its own fan), nct6687
# the board's fan controller. Values in millidegrees, fan in RPM.
cpu=""
gpu=""
fan=""
for d in /sys/class/hwmon/hwmon*; do
    [ -r "$d/name" ] || continue
    name=$(cat "$d/name" 2>/dev/null)
    case "$name" in
        k10temp) cpu=$(cat "$d/temp1_input" 2>/dev/null) ;;
        amdgpu)
            gpu=$(cat "$d/temp1_input" 2>/dev/null)
            [ -r "$d/fan1_input" ] && fan=$(cat "$d/fan1_input" 2>/dev/null)
            ;;
        nct6687)
            [ -z "$fan" ] && fan=$(cat "$d/fan1_input" 2>/dev/null)
            ;;
    esac
done
printf '%s|%s|%s\n' "${cpu%???}" "${gpu%???}" "$fan"
