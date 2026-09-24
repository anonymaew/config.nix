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
    formatter = pkgs.nixfmt;
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

    deploy.nodes.linode-us = {
      # No DNS name yet — deploy against the Linode's public IP.
      hostname = "45.33.39.244";
      interactiveSudo = true;
      profiles.system = {
        # Deploy as root (declared in hosts/linode-us/default.nix): napatsc
        # has no password/sudo setup, so non-interactive deploy-rs can't su to
        # root. Switch to "napatsc" only if sudo access is configured for it.
        sshUser = "root";
        user = "root";
        path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.linode-us;
      };
    };
  };
}
