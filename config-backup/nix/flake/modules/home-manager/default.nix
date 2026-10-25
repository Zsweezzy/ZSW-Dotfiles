# Which home-manager modules make up the configuration. Bodies live in
# src/<feature>/modules/home-manager.nix; this file is only the list.
{ ... }:
{
  imports = [
    ../../../src/home/modules/home-manager.nix
    ../../../src/packages/modules/home-manager.nix
    ../../../src/shell/modules/home-manager.nix
    ../../../src/shell-ext/modules/home-manager.nix
    ../../../src/git/modules/home-manager.nix
    ../../../src/editors/modules/home-manager.nix
    ../../../src/hyprland/modules/home-manager.nix
    ../../../src/fonts/modules/home-manager.nix
    ../../../src/gui/modules/home-manager.nix
    ../../../src/services/modules/home-manager.nix
  ];
}
