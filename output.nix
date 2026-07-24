# output — flake outputs (deploy-rs only)
# nix-darwin and NixOS configurations are in modules/darwin.nix and modules/nixos.nix
{ self, inputs, ... }:
let
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
