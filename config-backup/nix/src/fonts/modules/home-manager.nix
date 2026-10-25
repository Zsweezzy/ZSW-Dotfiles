{ pkgs, ... }:
{
  # Declarative fonts. The system font packages stay installed until this is
  # verified in KDE/Chrome; fontconfig just gains these directories.
  # gsfonts has no nixpkgs package, so the system one stays.
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.fantasque-sans-mono
    nerd-fonts.meslo-lg
    nerd-fonts.symbols-only # was awesome-terminal-fonts
    fira-sans
    hack-font
    liberation_ttf
    dejavu_fonts
    ttf-bitstream-vera
    cantarell-fonts
    adwaita-fonts
    open-sans
  ];

  # Custom synthetic oblique/bold rules. This used to be
  # ~/.config/fontconfig/fonts.conf, but that path is now owned by
  # fonts.fontconfig. conf.d is read by fontconfig as well.
  # Backup: ~/Backups/fontconfig-fonts.conf.bak-2026-10-17
  fonts.fontconfig.configFile."user-fake-oblique" = {
    enable = true; # legacy default is false while home.stateVersion < 26.11
    source = ../assets/10-user-fake-oblique.conf;
  };
}
