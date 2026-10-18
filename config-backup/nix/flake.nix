{
  description = "home-manager (CachyOS hybrid)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # GPU driver paths for nix packages on this non-NixOS host (Hyprland).
    nixGL = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixGL, ... }:
    import ./flake { inherit nixpkgs home-manager nixGL; };
}
