#!/usr/bin/env bash
# Install the system-side GPU glue that lets Nix GUI apps use the GPU.
# Needs root. Idempotent; re-run after a reinstall (see bootstrap/restore.sh).
#
# Creates /run/opengl-driver -> the Nix mesa in ~/.nix-profile, which is where
# Nix glvnd/vulkan-loader expect the driver tree.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Drop JSONs from an earlier attempt that pointed at the *system* mesa: those
# cannot load from a Nix process (system-only deps) and log loader errors.
rm -f /etc/glvnd/egl_vendor.d/50-nix-mesa.json /etc/vulkan/icd.d/50-nix-radeon.json

install -Dm644 "$here/nix-opengl-driver.conf" /etc/tmpfiles.d/nix-opengl-driver.conf

# Purge the tree first: an existing symlink into ~/.nix-profile makes
# systemd-tmpfiles refuse to descend ("unsafe path transition"), so a changed
# layout would silently not apply.
rm -rf /run/opengl-driver

# Create the tree now instead of waiting for the next boot.
systemd-tmpfiles --create /etc/tmpfiles.d/nix-opengl-driver.conf

test -e /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
  || { echo "FAIL: no EGL vendor json in profile - is mesa in packages.nix?" >&2; exit 1; }

echo "ok: /run/opengl-driver -> ~/.nix-profile (nix mesa)"
