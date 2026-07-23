{
  pkgs,
  vars,
  lib,
  brew-nix,
  ...
}:
{
  # ── Users ──────────────────────────────────────────────────────────
  users.users.${vars.name} = {
    name = "${vars.name}";
    home = "/Users/${vars.name}";
    shell = pkgs.zsh;
  };

  # ── Brew-Nix ──────────────────────────────────────────────────────
  brew-nix.enable = true;

  # ── Nix settings ──────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      use-xdg-base-directories = true;
      secret-key-files = [ "/etc/nix/nix-secret-key" ];
    };
    gc = {
      automatic = true;
      options = "--delete-generations +8";
    };
    optimise.automatic = true;
    settings.auto-optimise-store = true;
  };

  # ── macOS system defaults ─────────────────────────────────────────
  system = {
    stateVersion = 7;
    primaryUser = vars.name;

    defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        persistent-apps = [ ];
        tilesize = 48;
        # lock when cursor is moved to bottom left
        wvous-bl-corner = 13;
      };
      controlcenter.BatteryShowPercentage = true;
      hitoolbox.AppleFnUsageType = "Show Emoji & Symbols";
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        _HIHideMenuBar = true;

        "com.apple.trackpad.scaling" = 3.0;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;

        AppleMetricUnits = 1;
        AppleMeasurementUnits = "Centimeters";
        AppleICUForce24HourTime = true;
      };
      menuExtraClock = {
        Show24Hour = true;
        ShowSeconds = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };
}
