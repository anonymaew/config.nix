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
        nixpkgs.overlays = import (rootPath + "/overlays/default.nix");
      }
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
                homeModules.git
                inputs.sops-nix.homeManagerModules.sops
                (rootPath + "/users/${user.username}")
                inputs.mac-app-util.homeManagerModules.default
                inputs.agent-skills.homeManagerModules.default

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
                self.homeModules.git
                self.homeModules.shell
                self.homeModules.skills
              ];
            };
          };
        }
      )
    ];
  };
}
