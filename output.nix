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
    deploy.nodes.homelab-n150 = {
      # Stable tailnet IP, not MagicDNS: `homelab`/`homelab-n150` name
      # resolution must not be in the path when the box is redeployed.
      hostname = "100.89.132.36";
      interactiveSudo = false;
      profiles.system = {
        # Root key auth is declared in hosts/homelab-n150/default.nix and is
        # installed on the live box; this removes the sudo prompt from deploys.
        sshUser = "root";
        user = "root";
        path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab-n150;
      };
    };

    # Second k3s node. Installed by nixos-anywhere; the tailnet IP is stable
    # per node key, so no MagicDNS dependency is needed to reach it.
    deploy.nodes.homelab-3070 = {
      hostname = "100.83.20.73";
      sshOpts = [
        "-o"
        "StrictHostKeyChecking=accept-new"
      ];
      interactiveSudo = false;
      profiles.system = {
        sshUser = "root";
        user = "root";
        path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.homelab-3070;
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
