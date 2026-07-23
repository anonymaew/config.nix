{
  self,
  nixpkgs,
  nix-darwin,
  home-manager,
  brew-nix,
  agent-skills,
  mac-app-util,
  deploy-rs,
  nix-rosetta-builder,
  sops-nix,
  ...
}@inputs:
let
  vars = {
    name = "napatsc";
  };
  system = "x86_64-linux";
  # Unmodified nixpkgs
  pkgs = import nixpkgs { inherit system; };
  # nixpkgs with deploy-rs overlay but force the nixpkgs package
  deployPkgs = import nixpkgs {
    inherit system;
    overlays = [
      deploy-rs.overlays.default
      (self: super: {
        deploy-rs = {
          inherit (pkgs) deploy-rs;
          lib = super.deploy-rs.lib;
        };
      })
    ];
  };
in
{
  formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
    system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style
  );
  darwinConfigurations = {
    macair = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./default.nix
        ./system.nix
        brew-nix.darwinModules.default
        home-manager.darwinModules.home-manager
        mac-app-util.darwinModules.default
        nix-rosetta-builder.darwinModules.default
        sops-nix.darwinModules.sops
        {
          nix-rosetta-builder.onDemand = true;
        }
        # Apply overlays (ld64 hardening fix, etc.)
        {
          nixpkgs.overlays = import ./overlays/default.nix;
        }
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              secrets-dir = self + "/secrets";
              inherit agent-skills;
            };
            users."${vars.name}" = {
              imports = [
                sops-nix.homeManagerModules.sops
                ./home.nix
                (./. + "/users/${vars.name}")
                mac-app-util.homeManagerModules.default
                agent-skills.homeManagerModules.default
                ./programs/skills
              ];
            };
          };
        }
      ];
      specialArgs = {
        inherit vars;
        inherit brew-nix;
      };
    };
  };
  nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./homelab/configuration.nix
      sops-nix.nixosModules.sops
    ];
    specialArgs = { inherit vars; secrets-dir = self + "/secrets"; };
  };
  deploy.nodes.homelab = {
    hostname = "homelab";
    interactiveSudo = true;
    profiles.system = {
      sshUser = "napatsc";
      user = "root";
      path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab;
    };
  };
  nixosConfigurations.hetzner-sg = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./hetzner/configuration.nix
      sops-nix.nixosModules.sops
    ];
    specialArgs = { inherit vars; secrets-dir = self + "/secrets"; };
  };
  deploy.nodes.hetzner-sg = {
    hostname = "hetzner-sg";
    interactiveSudo = true;
    profiles.system = {
      sshUser = "napatsc";
      user = "root";
      path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.hetzner-sg;
    };
  };
}
