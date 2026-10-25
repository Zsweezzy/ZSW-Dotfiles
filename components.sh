# Component map shared by backup.sh and apply.sh.
# Each entry is "<absolute live path>|<path inside the theme folder>".
# Keep this the only place the mapping is written down.

PAIRS=(
  # Terminal
  "$HOME/.config/oh-my-posh|oh-my-posh"
  "$HOME/.config/fastfetch|fastfetch"
  "$HOME/.config/fish|fish"
  "$HOME/.config/kitty|kitty"
  "$HOME/.config/alacritty|alacritty"

  # GTK
  "$HOME/.config/gtk-3.0|gtk/gtk-3.0"
  "$HOME/.config/gtk-4.0|gtk/gtk-4.0"
  "$HOME/.gtkrc-2.0|gtk/.gtkrc-2.0"

  # Editors / apps
  "$HOME/.config/nvim|nvim"

  # mpv (Flatpak) — YouTube-style OSC + Tokyo Night Moon colors
  "$HOME/.var/app/io.mpv.Mpv/config/mpv|mpv"

  # Spicetify (user content only — Themes, Extensions, CustomApps,
  # plus the spicetify-cli config & active theme)
  "$HOME/.spicetify/Themes|spicetify/workspace/Themes"
  "$HOME/.spicetify/Extensions|spicetify/workspace/Extensions"
  "$HOME/.spicetify/CustomApps|spicetify/workspace/CustomApps"
  "$HOME/.config/spicetify/Themes|spicetify/config/Themes"
  "$HOME/.config/spicetify/config-xpui.ini|spicetify/config/config-xpui.ini"

  # KDE Plasma theme
  "$HOME/.local/share/plasma/desktoptheme|plasma/desktoptheme"
  "$HOME/.local/share/plasma/look-and-feel|plasma/look-and-feel"
  "$HOME/.local/share/plasma/plasmoids|plasma/plasmoids"
  "$HOME/.local/share/plasma/wallpapers|plasma/wallpapers"
  "$HOME/.local/share/color-schemes|colorschemes"
  "$HOME/.local/share/aurorae|aurorae"
  "$HOME/.local/share/wallpapers|wallpapers"

  # KDE config (theme/layout only — no activity history, wallets, or session state)
  "$HOME/.config/kdeglobals|kde/kdeglobals"
  "$HOME/.config/kwinrc|kde/kwinrc"
  "$HOME/.config/kwinrulesrc|kde/kwinrulesrc"
  "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc|plasma/plasma-org.kde.plasma.desktop-appletsrc"
  "$HOME/.config/plasmashellrc|plasma/plasmashellrc"
  "$HOME/.config/plasmarc|plasma/plasmarc"
  "$HOME/.config/kscreenlockerrc|kde/kscreenlockerrc"
  "$HOME/.config/ksplashrc|kde/ksplashrc"
  "$HOME/.config/kcmfonts|kde/kcmfonts"
)
