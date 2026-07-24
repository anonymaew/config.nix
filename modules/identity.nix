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
        default = "74C4 EA31 DDE9 7553 0A15  B036 A46D 60E5 7550 D198";
        description = "User's PGP key fingerprint";
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
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDe/pgCTH3B4AzKAVMcA2l42jJq2K4tiObkLNsvbrJZG napatsc@macair"
      ];
    };
  };

  # Git identity for HM (receives user via extraSpecialArgs)
  config.home.modules.git = { user, ... }: {
    programs.git.settings.user = {
      name = user.fullName;
      inherit (user) email;
    };
    programs.git.signing.key = user.pgpKey;
  };
}
