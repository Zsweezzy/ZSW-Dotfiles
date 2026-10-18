# config-backup

Private snapshot of my CachyOS + Niri/Hyprland desktop configuration, so a
reinstall or a dead disk is recoverable.

This is a **backup mirror**, not a live dotfiles manager: files are copied into
the repo (`rsync --copy-links`), so the repo holds real content rather than the
`/nix/store` symlinks Home Manager leaves behind in `$HOME`.

## Layout

| Folder | Source | Notes |
|---|---|---|
| `config/` | `~/.config` | Curated: see exclusions below |
| `home/` | loose `~` dotfiles | `.bashrc`, `.zshrc`, `.zprofile`, `.gitconfig`, `.gtkrc-2.0`, … |
| `nix/` | `~/nix` | The Home Manager flake. **This repo is its only remote** — `~/nix` has no origin of its own. |

## Syncing

```bash
./backup.sh          # rsync everything in, commit, push
```

Safe to re-run; `rsync --delete` keeps each mirror exact. The script also greps
the staged diff for token-shaped strings and aborts rather than commit one.

## Restoring

```bash
git clone git@github.com:Zsweezzy/config-backup.git ~/config-backup

# Config (review the diff first — this overwrites)
rsync -a ~/config-backup/config/ ~/.config/
rsync -a ~/config-backup/home/   ~/

# Nix / Home Manager
cp -a ~/config-backup/nix ~/nix
cd ~/nix && nix run home-manager -- switch --flake .#maxii
```

Nix-managed files (`~/.config/kitty/kitty.conf`, `~/.config/systemd/user/*`,
`~/.config/git/config`, …) are **recreated by `home-manager switch`** from
`nix/`; the copies in `config/` are there so you can read them without Nix.

## What is deliberately NOT backed up

**Secrets** — excluded via `.gitignore`, never committed:
`~/.config/gh/hosts.yml` (OAuth token), `~/.config/sunshine/credentials/`,
`~/.config/kdeconnect/` (TLS key), `~/.config/borg/`, `Photon Studio/auth`,
`Tenzen/auth`, `~/.npmrc`, `~/.pulse-cookie`, `~/.claude.json`.
Plus, by policy: `~/.ssh`, `~/.gnupg`, `~/.pki`. Re-auth / re-pair after a
restore.

**Browser profiles and app runtime state** (~2.9 GB of `~/.config`): `mozilla`,
`Ferdium`, `google-chrome`, `net.imput.helium`, `Vortex`, `OptiscalerClient`,
`spotifast`, `eDEX-UI`, `terminal-browser-*`, `GenOffice`, `MrCode`, `Claude`,
`Tenzen`, `Photon Studio`, and their caches. Cookies, history and session
databases belong in a browser sync/export, not in git.

**Deliberately excluded for size or duplication:**

| Path | Size | Why | Covered by |
|---|---|---|---|
| `~/.config/opencode` | 323 MB | app state, not config | `Zsweezzy/opencode-backup` |
| `~/.local/bin` | 1.4 GB | AppImages + compiled binaries + `/nix/store` symlinks | toolchain / their own repos |
| `~/projects`, `~/Desktop`, `~/Documents`, `~/Downloads`, `~/games` | — | data, not config | separate backup |
| `~/.cache`, `~/.var` | — | caches | n/a |
| `~/.config/quickshell` | 10 MB | *included*, despite the size — it is hand-written QML | — |

Themes (`bwzs/`, `tokyonight-moon/`) live in the separate **public**
`Zsweezzy/dotfiles` repo with the same `backup.sh` pattern. `~/.config/spicetify`
is mirrored in both; harmless overlap.

## Known gaps

- `~/nix` history is flattened here — the flake's own git log is not in this
  repo. Add an `origin` to `~/nix` if that history matters.
- `/etc` files this setup depends on (e.g. `tmpfiles.d/nix-opengl-driver.conf`)
  are root-owned and are restored from `nix/src/gpu/install.sh`.
- `~/.config/spicetify` token files and `Trust Tokens*` databases are ignored.
