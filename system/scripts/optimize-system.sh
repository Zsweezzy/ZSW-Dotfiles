#!/usr/bin/env bash
# ============================================================================
#  optimize-system.sh - privileged ("root") performance tweaks for C3PO
# ============================================================================
#  Rationale and the full written spec live in ../11-root-actions.md
#
#  Everything here needs sudo. Nothing happens without your confirmation.
#  Every item is idempotent and individually revertable.
#
#  Usage:
#     sudo ./optimize-system.sh            # interactive; asks before each item
#     sudo ./optimize-system.sh --yes      # accept the recommended answer
#     sudo ./optimize-system.sh --revert   # undo every item this script manages
#
#  Backups go to /root/system-opt-backups-<timestamp>/
# ============================================================================
set -euo pipefail

YES=0; REVERT=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes)  YES=1 ;;
    --revert)  REVERT=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must run as root:   sudo $0" >&2
  exit 1
fi

readonly ENVFILE=/etc/environment
readonly GAMEMODE_INI=/etc/gamemode.ini
readonly UDEV_RULE=/etc/udev/rules.d/99-amdgpu-gamemode.rules
readonly SYSCTL_FILE=/etc/sysctl.d/99-gaming.conf
readonly MARK_BEGIN='# --- system-opt (managed by optimize-system.sh) ---'
readonly MARK_END='# --- end system-opt ---'
readonly TARGET_USER="${SUDO_USER:-maxii}"
BACKUP_DIR="/root/system-opt-backups-$(date +%Y%m%d-%H%M%S)"

log()  { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
ask() { # ask "<prompt>" <default y|n> ; 0 = yes
  local prompt="$1" default="$2" answer
  if [ "$YES" -eq 1 ]; then
    [ "$default" = y ]
    return $?
  fi
  if [ "$default" = y ]; then read -r -p "   $prompt [Y/n] " answer || answer=""
  else                        read -r -p "   $prompt [y/N] " answer || answer=""; fi
  answer="${answer:-$default}"
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
backup() {
  [ -e "$1" ] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -a "$1" "$BACKUP_DIR/$(printf '%s' "$1" | tr '/' '_')"
  note "backed up $1"
}

# ------------------------------------------------------------------ revert ---
if [ "$REVERT" -eq 1 ]; then
  log "Reverting every root item"
  [ -f "$ENVFILE" ] && { sed -i "\|$MARK_BEGIN|,\|$MARK_END|d" "$ENVFILE"; \
                         note "removed marked block from /etc/environment"; }
  [ -f "$GAMEMODE_INI" ] && rm -f "$GAMEMODE_INI" && note "removed $GAMEMODE_INI"
  [ -f "$UDEV_RULE" ]    && rm -f "$UDEV_RULE"    && note "removed $UDEV_RULE"
  [ -f "$SYSCTL_FILE" ]  && rm -f "$SYSCTL_FILE"  && note "removed $SYSCTL_FILE"
  systemctl enable NetworkManager-wait-online.service >/dev/null 2>&1 \
    && note "re-enabled NetworkManager-wait-online.service" || true
  udevadm control --reload-rules 2>/dev/null || true
  sysctl --system >/dev/null 2>&1 || true
  log "Done (a reboot makes it fully effective)"
  exit 0
fi

log "Backups will go to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# ------------------------------------------------------- 1. /etc/environment -
log "1) System-wide environment variables (recommended: yes)"
note "MESA_SHADER_CACHE_MAX_SIZE=12G  ENABLE_LAYER_MESA_ANTI_LAG=1"
note "PROTON_LOCAL_SHADER_CACHE=1  PROTON_DXVK_LOWLATENCY=1"
if ask "Append these to /etc/environment?" y; then
  backup "$ENVFILE"
  if grep -qF "$MARK_BEGIN" "$ENVFILE" 2>/dev/null; then
    note "block already present - left untouched"
  else
    { printf '\n%s\n' "$MARK_BEGIN"
      printf 'MESA_SHADER_CACHE_MAX_SIZE=12G\n'
      printf 'ENABLE_LAYER_MESA_ANTI_LAG=1\n'
      printf 'PROTON_LOCAL_SHADER_CACHE=1\n'
      printf 'PROTON_DXVK_LOWLATENCY=1\n'
      printf '%s\n' "$MARK_END"; } >> "$ENVFILE"
    note "appended the marked block"
  fi
else note "skipped"; fi

# ------------------------------------------ 2. NetworkManager-wait-online -----
log "2) Disable NetworkManager-wait-online (recommended: yes)"
note "pure boot-time delay on a desktop; no functional loss"
if ask "Disable it?" y; then
  systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 \
    && note "disabled" || note "already disabled"
else note "skipped"; fi

# ----------------------------------------------------------- 3. sysctls -----
log "3) /etc/sysctl.d/99-gaming.conf (recommended: yes)"
note "vm.page-cluster=0 (zram reads), fq+bbr (throughput/latency)"
if ask "Write it?" y; then
  backup "$SYSCTL_FILE"
  {
    echo "# managed by optimize-system.sh"
    echo "vm.page-cluster = 0"
    if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
      echo "net.core.default_qdisc = fq"
      echo "net.ipv4.tcp_congestion_control = bbr"
    else
      echo "# bbr not available in this kernel - skipped"
    fi
  } > "$SYSCTL_FILE"
  sysctl --system >/dev/null 2>&1 || true
  note "written and applied"
  note "NOTE: bpftune may override network sysctls at runtime (item 6)"
else note "skipped"; fi

# ---------------------------------------------------------- 4. GameMode -----
log "4) Make GameMode actually effective (recommended: no)"
note "gamemoded is a user service with CapEff=0 and no system unit, so"
note "gamemoderun currently cannot renice or set GPU clocks. This installs"
note "/etc/gamemode.ini + a udev rule so it can set the dGPU to 'high'."
if id -nG "$TARGET_USER" 2>/dev/null | grep -qw video; then
  note "user $TARGET_USER is in group 'video'  -> rule can work"
  gm_ok=1
else
  note "WARNING: user $TARGET_USER is NOT in group 'video'; the rule will not"
  note "grant access. Add them first:  usermod -aG video $TARGET_USER"
  gm_ok=0
fi
if ask "Install GameMode configuration anyway?" n; then
  if [ "$gm_ok" -eq 1 ]; then
    backup "$GAMEMODE_INI"; backup "$UDEV_RULE"
    cat > "$GAMEMODE_INI" <<'INI'
[general]
renice=0

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=1
amd_performance_level=high
INI
    cat > "$UDEV_RULE" <<'RULE'
# Allow GameMode to set the AMD dGPU (card1) performance level without root.
KERNEL=="card1", SUBSYSTEM=="drm", DRIVERS=="amdgpu", \
  RUN+="/bin/sh -c 'chgrp video /sys/class/drm/card1/device/power_dpm_force_performance_level; chmod g+w /sys/class/drm/card1/device/power_dpm_force_performance_level'"
RULE
    udevadm control --reload-rules && udevadm trigger --subsystem-match=drm || true
    note "installed /etc/gamemode.ini and the udev rule"
  else
    note "skipped (user not in 'video' group)"
  fi
else note "skipped"; fi

# -------------------------------------------------------- 5. sched_ext ------
log "5) sched_ext scheduler (print-only; experimental)"
note "scx_loader is running but nothing is attached; kernel is on EEVDF."
note "scx_lavd / scx_bpfland are installed. To try one yourself:"
note "    scxctl list"
note "    scxctl start --sched scx_lavd     # check 'scxctl start --help'"
note "    scxctl stop                       # back to EEVDF"

# ---------------------------------------------------------- 6. bpftune ------
log "6) bpftune auto-tuner (recommended: no)"
note "actively rewrites network sysctls at runtime; disable if you want your"
note "own sysctls to be final. A user policy call."
if ask "Disable bpftune?" n; then
  systemctl disable --now bpftune.service >/dev/null 2>&1 && note "disabled" || true
else note "skipped"; fi

# --------------------------------------------- 7. optional service trims ----
log "7) Optional trims (informational - nothing changed)"
note "nordvpnd   ~114 MB   -> systemctl disable --now nordvpnd.service"
note "tailscaled  ~45 MB   -> systemctl disable --now tailscaled.service"
note "(two VPN daemons run at once; keep them only if you need both live)"
note "vice (clip recorder, ~30 MB + GPU encode) is a USER service:"
note "    systemctl --user disable --now vice.service"

# ------------------------------------------------------ 8. kernel cmdline ---
log "8) Kernel cmdline ideas (print-only; GRUB)"
note "Bootloader is GRUB. Edit GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub,"
note "then:  grub-mkconfig -o /boot/grub/grub.cfg   and reboot."
note "  mitigations=off   biggest free CPU win, but drops hardening (your call)"
note "  preempt=full      better frame-time consistency (PREEMPT_DYNAMIC kernel)"
note "  nowatchdog is ALREADY present - nothing to add there."

log "Finished"
note "Backups: $BACKUP_DIR"
note "Undo everything:  sudo $0 --revert"
note "A reboot (or re-login) is needed for /etc/environment changes to apply."
