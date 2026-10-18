# darwin — nix-darwin configuration
{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  rootPath = ../.;
in
{
  # ── nix-darwin modules ─────────────────────────────────────────────
  options.darwin.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "nix-darwin modules";
  };

  # ── User creation for nix-darwin ───────────────────────────────────
  config.darwin.modules.identity = { user, pkgs, ... }: {
    users.users.${user.username} = {
      name = "${user.username}";
      home = "/Users/${user.username}";
      shell = pkgs.zsh;
    };
    system.primaryUser = user.username;
  };

  # ── Darwin configuration ───────────────────────────────────────────
  config.flake.darwinConfigurations.macair = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = {
      user = config.user;
      homeModules = config.home.modules;
    };
    modules = [
      (rootPath + "/hosts/macair")
      inputs.determinate.darwinModules.default
      inputs.brew-nix.darwinModules.default
      inputs.home-manager.darwinModules.home-manager
      inputs.mac-app-util.darwinModules.default
      inputs.sops-nix.darwinModules.sops
      # User identity (from flake-parts options via deferredModule)
      config.darwin.modules.identity
      (
        {
          config,
          user,
          homeModules,
          ...
        }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit user;
            };
            users."${user.username}" = {
              imports = [
                inputs.sops-nix.homeManagerModules.sops
                (rootPath + "/users/${user.username}")
                inputs.mac-app-util.homeManagerModules.default
                inputs.agent-skills.homeManagerModules.default

                # macOS System Settings (user scope): declares
                # programs.nix-plist-manager.options in hosts/macair/mac.nix
                inputs.nix-plist-manager.homeManagerModules.default
                (rootPath + "/hosts/macair/mac.nix")
              ]
              # Auto-discovered programs (flake.homeModules) and the identity
              # git fragment (config.home.modules) — no per-program listing.
              ++ lib.attrValues homeModules
              ++ lib.attrValues self.homeModules;
            };
          };
        }
      )
    ];
  };
}
