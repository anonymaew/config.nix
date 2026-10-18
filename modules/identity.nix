# identity — user identity (single source of truth)
# Flake-parts module following the dendritic pattern.
{ lib, config, ... }:
let
  userOption = lib.types.submodule {
    options = {
      username = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "napatsc";
        description = "Primary user username";
      };
      fullName = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "Napat Srichan";
        description = "User's full name";
      };
      email = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "me@napatsc.com";
        description = "User's email address";
      };
      pgpKey = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "6092 759D C395 82FC 366A  83A8 92DD 8B79 5345 9405";
        description = "User's PGP key fingerprint";
      };
      sshKey = lib.mkOption {
        type = lib.types.singleLineStr;
        default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDe/pgCTH3B4AzKAVMcA2l42jJq2K4tiObkLNsvbrJZG napatsc@macair";
        description = "User's SSH public key (authorized on every host)";
      };
    };
  };
in
{
  # ── User identity options ──────────────────────────────────────────
  options.user = lib.mkOption {
    type = userOption;
    default = { };
    description = "Primary user identity";
  };

  # ── Lower-level modules (deferred) ────────────────────────────────
  options.nixos.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "NixOS modules";
  };

  options.home.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Home Manager modules";
  };

  # ── Default implementations ────────────────────────────────────────
  # User creation for NixOS (receives user via specialArgs)
  config.nixos.modules.identity = { user, ... }: {
    users.users.${user.username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ user.sshKey ];
    };
  };

  # Git identity for HM (receives user via extraSpecialArgs)
  config.home.modules.git = { user, ... }: {
    programs.git.settings.user = {
      name = user.fullName;
      inherit (user) email;
    };
    programs.git.signing = {
      key = user.pgpKey;
      signByDefault = true;
    };
  };
}
