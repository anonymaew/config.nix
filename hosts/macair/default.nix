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

    # Use the build machines below (Determinate renders /etc/nix/machines
    # itself — nix-darwin's nix.* options are inert when nix.enable = false).
    distributedBuilds = true;

    # nix-rosetta-builder's Lima VM: builds aarch64-linux natively and
    # x86_64-linux via Rosetta 2. The module's own nix.buildMachines option is
    # only rendered when nix.enable = true, so register it here instead.
    buildMachines = [
      {
        hostName = "rosetta-builder";
        sshUser = "builder";
        sshKey = "/var/lib/rosetta-builder/ssh_user_ed25519_key";
        protocol = "ssh-ng";
        systems = [
          "aarch64-linux"
          "x86_64-linux"
        ];
        maxJobs = 8;
        speedFactor = 1;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
        mandatoryFeatures = [ ];
      }
    ];
  };

  # nix-rosetta-builder module (imported in modules/darwin.nix).
  # onDemand = the VM powers itself off after inactivity (saves ~6GiB RAM on
  # a laptop); the first Linux build boots it in a few seconds.
  nix-rosetta-builder = {
    enable = true;
    onDemand = true;
  };

  launchd.daemons.nix-gc = {
    command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-generations +4 7d";
    serviceConfig.StartCalendarInterval = {
      Hour = 3;
      Minute = 15;
    };
  };

  # ── PAM / sudo with Touch ID ─────────────────────────────────────
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    # allow Touch ID sudo inside tmux/screen (bootstrap-session reattach)
    reattach = true;
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

      # menu bar: [hide] In Full Screen Only
      CustomUserPreferences = {
        "NSGlobalDomain".AppleMenuBarVisibleInFullscreen = false;
        "com.apple.controlcenter".AutoHideMenuBarOption = 2;
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";

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
