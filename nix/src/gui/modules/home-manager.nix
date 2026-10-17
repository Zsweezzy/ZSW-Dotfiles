{ pkgs, ... }:
{
  # GUI/GL clients from Nix now that Nix apps can reach the GPU (see src/gpu/).
  # KDE Plasma, Hyprland itself, Chrome and Flatpaks stay on the system, and the
  # system packages below are left installed until the Nix ones are verified.
  home.packages = with pkgs; [
    kitty # terminal, EGL
    waybar
    rofi
    satty # screenshot annotator, needs EGL
    nwg-look # GTK settings
    meld
  ];
}
