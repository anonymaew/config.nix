{
  config,
  pkgs,
  lib,
  ...
}:
{
  # ── Brew-Nix ──────────────────────────────────────────────────────
  brew-nix.enable = true;

  # ── Nix settings ──────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  # disable vanilla nix; use determinate-nix
  nix.enable = false;
  determinateNix = {
    enable = true;
    determinateNixd.garbageCollector.strategy = "disabled";
    customSettings.auto-optimise-store = true;
  };

  launchd.daemons.nix-gc = {
    command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-generations +4 7d";
    serviceConfig.StartCalendarInterval = {
      Hour = 3;
      Minute = 15;
    };
  };

  # ── macOS system defaults ─────────────────────────────────────────
  system = {
    stateVersion = 7;

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
