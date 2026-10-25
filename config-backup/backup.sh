#!/usr/bin/env bash
# backup.sh — mirror the curated parts of $HOME into this repo, then commit & push.
#
# Layout:
#   config/  <- ~/.config, minus browser profiles / app runtime state / caches
#   home/    <- loose ~ dotfiles (shell rc, gitconfig, gtkrc-2.0, ...)
#   nix/     <- ~/nix (the Home Manager flake; this repo is its only remote)
#
# Symlinks are dereferenced (--copy-links): Home Manager turns many of these
# paths into symlinks into /nix/store, and a backup of dead store links is
# worthless.
#
# Usage: ./backup.sh      (safe to run repeatedly; safe to run from cron)
# Restore: see README.md
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

# Directories under ~/.config that are browser profiles, app runtime state or
# caches rather than configuration. See README.md for the reasoning per entry.
CONFIG_EXCLUDES=(
  mozilla Ferdium opencode OptiscalerClient Vortex google-chrome
  net.imput.helium spotifast eDEX-UI opendeck Claude MrCode GenOffice
  Tenzen "Photon Studio" Electron unity3d steamachievementnotifierv1.9
  kdeconnect borg dconf pulse session libaccounts-glib pika-backup
  monitor-backup-2026-10-09_21-31-14
)

# Some of these are Chromium/Electron profiles that live under a shared prefix.
CONFIG_PREFIX_EXCLUDES=( terminal-browser- )

EXCL=()
for d in "${CONFIG_EXCLUDES[@]}"; do EXCL+=( --exclude "/$d" ); done
for p in "${CONFIG_PREFIX_EXCLUDES[@]}"; do EXCL+=( --exclude "/$p*" ); done
EXCL+=(
  --exclude '.git/'           # waybar/quickshell are git checkouts — keep the
  --exclude '/logs/'          #   working tree, a gitlink would be empty
  --exclude '/credentials/'   # sunshine remote-desktop creds
  --exclude '*.log*'
  --exclude '/buffers/'       # micro undo history — holds file contents
  --exclude '/watch_later/'   # mpv resume state
  --exclude '/Users/'         # spotify account state
  --exclude '*.lock'
  --exclude 'Singleton*'      # Chromium/Electron runtime locks — dangle once the
                              #   app exits, which aborts rsync's copy-links pass
  --exclude '*.sqlite3'
  --exclude '*.bak*'          # stale pre-edit copies; git history covers this
)

mkdir -p config home nix

rsync -a --copy-links --delete "${EXCL[@]}" "$HOME/.config/" config/

# Loose dotfiles worth restoring; everything else in ~ is a toolchain dir
# (.cargo, .rustup, .venv, ...) or a secret (.npmrc, .pulse-cookie).
rsync -a --copy-links --delete --ignore-missing-args \
  "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_logout" "$HOME/.profile" \
  "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zsh" \
  "$HOME/.gtkrc-2.0" "$HOME/.gitconfig" "$HOME/.win11.draft.txt" \
  home/

# ~/nix was moved out of $HOME; keep the last copy instead of --delete-ing it.
if [[ -d "$HOME/nix" ]]; then
  rsync -a --copy-links --delete --exclude '/.git/' --exclude '/result' \
    "$HOME/nix/" nix/
else
  echo "skip: ~/nix (no longer exists; repo copy kept as-is)"
fi

git add -A

# Safety net: .gitignore should already keep secrets out; this catches a
# secret that slipped into a file with an innocent name.
if git diff --cached --name-only -z \
   | xargs -0 -r grep -lIE 'gho_[A-Za-z0-9]{20}|ghp_[A-Za-z0-9]{20}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY' 2>/dev/null \
   | grep -q .; then
  echo "ABORT: staged file(s) look like they contain a secret — nothing committed." >&2
  exit 1
fi

if git diff --cached --quiet; then
  echo "Nothing to commit — repo up to date."
else
  git commit -m "Backup config ($(date +%Y-%m-%d))"
  git push
  echo "Pushed to origin/main."
fi
