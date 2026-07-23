{
  self,
  inputs,
  ...
}:
let
  vars = {
    name = "napatsc";
  };
  # nixpkgs with deploy-rs lib overlay (x86_64-linux for NixOS deployment)
  deployPkgs = (inputs.nixpkgs.legacyPackages.x86_64-linux).extend (
    final: prev: {
      deploy-rs = {
        inherit (prev) deploy-rs;
        lib = inputs.deploy-rs.lib.x86_64-linux;
      };
    }
  );
in
{
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt-rfc-style;
  };

  flake = {
    darwinConfigurations.macair = inputs.nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./hosts/macair
        inputs.brew-nix.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        inputs.mac-app-util.darwinModules.default
        inputs.nix-rosetta-builder.darwinModules.default
        inputs.sops-nix.darwinModules.sops
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
              inherit vars;
              secrets-dir = self + "/secrets";
              inherit (inputs) agent-skills;
            };
            users."${vars.name}" = {
              imports = [
                inputs.sops-nix.homeManagerModules.sops
                ./home.nix
                (./. + "/users/${vars.name}")
                inputs.mac-app-util.homeManagerModules.default
                inputs.agent-skills.homeManagerModules.default
                ./programs/skills

                # Programs — individual Home Manager modules
                self.homeModules.yabai
                self.homeModules.skhd
                # self.homeModules.sketchybar # deactivated
                self.homeModules.ghostty
                self.homeModules.aerospace
                self.homeModules.pass
                self.homeModules.neovim
                self.homeModules.tmux
                self.homeModules.direnv
                self.homeModules.starship
                self.homeModules.taskwarrior
                self.homeModules.gnupg
                self.homeModules.pi
                self.homeModules.k9s
              ];
            };
          };
        }
      ];
      specialArgs = {
        inherit vars;
        inherit (inputs) brew-nix;
      };
    };

    nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/homelab
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {
        inherit vars;
        secrets-dir = self + "/secrets";
      };
    };

    nixosConfigurations.hetzner-sg = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/hetzner
        inputs.sops-nix.nixosModules.sops
      ];
      specialArgs = {
        inherit vars;
        secrets-dir = self + "/secrets";
      };
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

    deploy.nodes.hetzner-sg = {
      hostname = "hetzner-sg";
      interactiveSudo = true;
      profiles.system = {
        sshUser = "napatsc";
        user = "root";
        path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.hetzner-sg;
      };
    };
  };
}
