{ config, pkgs, ... }:
{
  home.username = "maxii";
  home.homeDirectory = "/home/maxii";
  home.stateVersion = "24.05";

  # Module list lives in flake.nix (single source); it used to be duplicated here.
  programs.home-manager.enable = true;
}
