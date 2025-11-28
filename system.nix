{vars, ...}: {
  system = {
    stateVersion = 4;
    primaryUser = vars.name;

    defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        persistent-apps = [];
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

  # TODO
  # - wallpaper
  # - display scale
}
