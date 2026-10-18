{ config, lib, pkgs, nixGL, ... }:
let
  # Pure AMD/mesa wrapper (upstream's plain `nixGL` auto-detects the GPU by
  # shelling out to nix at login; this one is enough on this machine).
  hyprNixGL = nixGL.packages.${pkgs.stdenv.hostPlatform.system}.nixGLIntel;
  hyprland = pkgs.hyprland;
in
{
  # Hyprland: keep tool-edited config writable via mkOutOfStoreSymlink
  xdg.configFile."hypr/hyprland.lua".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/src/hyprland/assets/hyprland.lua";

  # Hyprland comes from nixpkgs because this host is not NixOS; it is started
  # through nixGL so the compositor finds the host GPU drivers.
  # xwayland: Hyprland spawns Xwayland from PATH for X11 apps (ONLYOFFICE, Wine).
  home.packages = [
    hyprland
    pkgs.xwayland
    hyprNixGL
  ];

  # start-hyprland wraps itself through nixGL when it is compiled with nix,
  # but it looks for a command literally named `nixGL`.
  home.file.".local/bin/nixGL" = {
    source = "${hyprNixGL}/bin/nixGLIntel";
    executable = true;
  };

  # Login-manager entry point. PATH must carry: the hyprland store bin (config
  # autostart and the ~/.local/bin scripts call bare `hyprctl`), the profile,
  # and ~/.local/bin (the nixGL shim above).
  home.file.".local/bin/hyprland-nix" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      export PATH="${hyprland}/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
      exec ${hyprland}/bin/start-hyprland "$@"
    '';
  };

  xdg.dataFile."wayland-sessions/hyprland-nix.desktop".text = ''
    [Desktop Entry]
    Name=Hyprland (nix)
    Comment=Hyprland from nixpkgs, launched through nixGL
    Exec=${config.home.homeDirectory}/.local/bin/hyprland-nix
    Type=Application
    DesktopNames=Hyprland
  '';
}
