# nixos — NixOS configurations
{
  self,
  inputs,
  config,
  ...
}:
let
  rootPath = ../.;
  # Every server host shares the same system/platform and the same base +
  # identity modules; hosts differ only by their own directory (and by any
  # extraModules a host needs, e.g. disko for the nixos-anywhere install).
  mkHost =
    { host, extraModules ? [ ] }:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        user = config.user;
      };
      modules = [
        (rootPath + "/hosts/${host}")
        inputs.sops-nix.nixosModules.sops
        # Determinate Nix replaces the upstream nix package + nix-daemon on
        # every NixOS host (enabled by default; nix.custom.conf keeps the
        # NixOS-generated settings).
        inputs.determinate.nixosModules.default
        config.nixos.modules.base
        config.nixos.modules.identity
      ] ++ extraModules;
    };
in
{
  # ── NixOS configurations ───────────────────────────────────────────
  # NOTE: the k3s node name is deliberately `homelab` on homelab-n150
  # (--node-name=homelab): 49 local-path PVs carry that nodeAffinity and
  # PV nodeAffinity is immutable.
  config.flake.nixosConfigurations.homelab-n150 = mkHost { host = "homelab-n150"; };
  config.flake.nixosConfigurations.linode-us = mkHost { host = "linode-us"; };
  # disko only partitions on the nixos-anywhere install; on a deployed system
  # it is inert (the host's fileSystems come from hosts/homelab-3070/disk-config.nix).
  config.flake.nixosConfigurations.homelab-3070 = mkHost {
    host = "homelab-3070";
    extraModules = [ inputs.disko.nixosModules.disko ];
  };
}
