{
  description = "My nix config";

  inputs = {
    # Nix Packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # MacOS Spacific Packages
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Home Manager for user-specific configs
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nixvim
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nixvim }:
    let
      vars = {
        name = "napatsc";
      };
    in
    {
      darwinConfigurations = {
        macair = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # backupFileExtension = "backup";
                users."${vars.name}" = import ./home.nix;
                sharedModules = [ nixvim.homeManagerModules.nixvim ];
              };
            }
          ];
          specialArgs = { inherit vars; };
        };
      };
    };
}
