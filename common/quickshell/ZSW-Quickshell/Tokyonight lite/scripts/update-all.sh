#!/usr/bin/env bash
# Everything behind the island's "Update all" button. One line per phase so
# the flyout can show where the run is; the last line is the verdict.
#
# Repos are the only root step: pacman through pkexec, and quickshell itself
# is the session's polkit agent, so the prompt is the island's own card.
# Flatpak and AppImages run as the user. yay refuses root, so its pacman step
# escalates per package (one polkit prompt per AUR package with an update).
set -u

failed=()
phase() { printf '%s\n' "$*"; }

phase "Repos"
pkexec pacman -Syu --noconfirm || failed+=("repos")

phase "Flatpak"
flatpak update -y >/dev/null 2>&1 || failed+=("flatpak")

phase "AUR"
# Nothing to do (the common case) costs one query and no prompt.
if yay -Qua 2>/dev/null | grep -q .; then
    yay -Sua --noconfirm --sudo pkexec >/dev/null 2>&1 || failed+=("AUR")
fi

phase "AppImages"
if command -v appimageupdatetool >/dev/null 2>&1; then
    # AppImages without embedded update information report an error; that is
    # not a failed run, so the exit code is ignored.
    find "$HOME/.local/bin" "$HOME/Applications" -maxdepth 1 -name '*.AppImage' \
        -exec appimageupdatetool -O {} \; >/dev/null 2>&1
else
    phase "AppImages skipped: yay -S appimageupdatetool-bin"
fi

if [ ${#failed[@]} -gt 0 ]; then
    printf 'Failed: %s\n' "$(IFS=', '; echo "${failed[*]}")"
    exit 1
fi

phase "Updated"
