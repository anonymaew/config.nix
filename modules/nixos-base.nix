# nixos-base — shared NixOS base for every server host
# Flake-parts module following the dendritic pattern. The NixOS module it
# defines is exposed as `config.nixos.modules.base` and merged into each
# server configuration by `modules/nixos.nix`; hosts only declare what is
# genuinely host-specific.
{ config, ... }:
{
  config.nixos.modules.base = { user, pkgs, ... }: {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.auto-optimise-store = true;
    # Pull prebuilt paths from the community cache as well as cache.nixos.org
    # (nix-community projects aren't always on the main cache).
    nix.settings.substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    nix.settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "builder:qPTpfl43MdQlIoXVLCvA0/II/esC9F2qhau7skLyV5Y="
    ];
    nix.settings.trusted-users = [
      "root"
      user.username
    ];
    nix.gc.automatic = true;
    nix.gc.options = "--delete-generations +8";
    nix.optimise.automatic = true;

    nixpkgs.config.allowUnfree = true;

    # Set your time zone.
    time.timeZone = "America/Los_Angeles";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    # Baseline tooling every server gets; hosts add their own on top.
    environment.systemPackages = with pkgs; [
      btop
      inetutils
      neovim
      uutils-coreutils-noprefix
      wget
    ];
  };
}
