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
    # homebrew without homebrew
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs.brew-api.follows = "brew-api";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # for MacOS apps fix
    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = {
    self,
    nixpkgs,
    nix-darwin,
    home-manager,
    brew-nix,
    nixvim,
    mac-app-util,
    deploy-rs,
    ...
  }: let
    vars = {
      name = "napatsc";
    };
  in {
    darwinConfigurations = {
      macair = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./default.nix
          ./system.nix
          brew-nix.darwinModules.default
          home-manager.darwinModules.home-manager
          mac-app-util.darwinModules.default
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users."${vars.name}".imports = [
                ./home.nix
                (./. + "/users/${vars.name}")
                nixvim.homeModules.nixvim
                mac-app-util.homeManagerModules.default
              ];
            };
          }
        ];
        specialArgs = {inherit vars;};
      };
    };
    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [./homelab/configuration.nix];
      specialArgs = {inherit vars;};
    };
    deploy.nodes.homelab = {
      hostname = "homelab";
      interactiveSudo = true;
      remoteBuild = true;
      profiles.system = {
        sshUser = "napatsc";
        user = "root";
        path =
          deploy-rs.lib.x86_64-linux.activate.nixos
          self.nixosConfigurations.homelab;
      };
    };
    nixosConfigurations.linode = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [./linode/configuration.nix];
      specialArgs = {inherit vars;};
    };
    deploy.nodes.linode = {
      hostname = "linode";
      interactiveSudo = true;
      remoteBuild = true;
      profiles.system = {
        sshUser = "napatsc";
        user = "root";
        path =
          deploy-rs.lib.x86_64-linux.activate.nixos
          self.nixosConfigurations.linode;
      };
    };
  };
}
