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
  # identity modules; hosts differ only by their own directory.
  mkHost =
    host:
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
      ];
    };
in
{
  # ── NixOS configurations ───────────────────────────────────────────
  config.flake.nixosConfigurations.homelab = mkHost "homelab";
  config.flake.nixosConfigurations.linode-us = mkHost "linode-us";
}
