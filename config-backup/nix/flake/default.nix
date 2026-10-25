{ nixpkgs, home-manager, nixGL }:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
in
{
  homeConfigurations.maxii = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit nixGL; };
    modules = [ ./modules/home-manager ];
  };
}
