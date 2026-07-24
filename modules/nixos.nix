# nixos — NixOS configurations
{
  self,
  inputs,
  config,
  ...
}:
let
  rootPath = ../.;
in
{
  # ── NixOS configurations ───────────────────────────────────────────
  config.flake.nixosConfigurations.homelab = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      user = config.user;
    };
    modules = [
      (rootPath + "/hosts/homelab")
      inputs.sops-nix.nixosModules.sops
      config.nixos.modules.identity
    ];
  };

  config.flake.nixosConfigurations.hetzner-sg = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      user = config.user;
    };
    modules = [
      (rootPath + "/hosts/hetzner")
      inputs.sops-nix.nixosModules.sops
      config.nixos.modules.identity
    ];
  };
}
