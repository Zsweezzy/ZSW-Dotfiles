#!/usr/bin/env bash
# ============================================================================
#  rollback-user-level.sh - undo the 2026-10-14 user-level changes
# ============================================================================
#  Restores:
#    - Hyprland config  -> the pre-edit reference backup
#    - Steam localconfig -> the backup taken just before the launch-options write
#    - MangoHud global conf -> its backup
#
#  Usage:
#     ./rollback-user-level.sh                 # restore all three
#     ./rollback-user-level.sh --strip-gamemoderun
#                                              # only remove 'gamemoderun ' from
#                                              # the uniform launch strings
#     ./rollback-user-level.sh --border-on      # just re-enable borderangle
#
#  Steam MUST be closed for any localconfig.vdf change.
# ============================================================================
set -euo pipefail

HYPR="$HOME/.config/hypr/hyprland.lua"
HYPR_BAK="$HOME/.config/hypr/hyprland.lua.bak-20261014-133556"
STEAMCFG="$HOME/.local/share/Steam/userdata/1145198416/config/localconfig.vdf"
STEAM_BAK="$HOME/.local/share/Steam/userdata/1145198416/config/localconfig.vdf.bak-20261014-172859-launchopts"
MANGOHUD="$HOME/.config/MangoHud/MangoHud.conf"
MANGOHUD_BAK="$HOME/.config/MangoHud/MangoHud.conf.bak-20261014-133556"

UNIFORM='ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_DXVK_LOWLATENCY=1 gamemoderun %command%'
NOGM='ENABLE_LAYER_MESA_ANTI_LAG=1 PROTON_LOCAL_SHADER_CACHE=1 PROTON_DXVK_LOWLATENCY=1 %command%'

need_steam_closed() {
  if pgrep -x steam >/dev/null 2>&1; then
    echo "Steam is running. Close it, then re-run." >&2
    exit 1
  fi
}

case "${1:-all}" in
  --strip-gamemoderun)
    need_steam_closed
    echo "Removing 'gamemoderun ' from the uniform launch strings..."
    python3 - "$STEAMCFG" "$UNIFORM" "$NOGM" <<'PY'
import io, sys, shutil, time
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(path, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    print("no uniform strings found - nothing to do"); raise SystemExit(0)
bak = "%s.bak-%s-strip-gm" % (path, time.strftime("%Y%m%d-%H%M%S"))
shutil.copy2(path, bak)
io.open(path, "w", encoding="utf-8").write(s.replace(old, new))
print("replaced %d occurrencess; backup: %s" % (n, bak))
PY
    ;;
  --border-on)
    if [ -f "$HYPR" ]; then
      cp -a "$HYPR" "$HYPR.bak-$(date +%Y%m%d-%H%M%S)-border-on"
      echo "Re-enabling borderangle (edit the file to set enabled = true)."
      echo "Note: 'hyprctl reload' is safe in this config."
    fi
    ;;
  all|"")
    need_steam_closed
    [ -f "$HYPR_BAK" ]   && cp -a "$HYPR_BAK" "$HYPR"           && echo "restored $HYPR"
    [ -f "$STEAM_BAK" ]  && cp -a "$STEAM_BAK" "$STEAMCFG"      && echo "restored $STEAMCFG"
    [ -f "$MANGOHUD_BAK" ] && cp -a "$MANGOHUD_BAK" "$MANGOHUD" && echo "restored $MANGOHUD"
    echo "Reloading Hyprland..."
    command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
    echo "Done."
    ;;
  *)
    echo "unknown option: $1" >&2; exit 2 ;;
esac
