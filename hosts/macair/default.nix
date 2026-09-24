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

    # Distributed builds via Determinate (it renders /etc/nix/machines itself —
    # nix-darwin's nix.* options are inert when nix.enable = false).
    distributedBuilds = true;

    # Use the upstream nixpkgs Rosetta builder (`darwin.linux-builder-vz`) in
    # place of the previous cpick/nix-rosetta-builder Lima VM. It runs the NixOS
    # builder guest on Apple's Virtualization.framework via pkgs.vzvm:
    # aarch64-linux natively, x86_64-linux via Rosetta (included on macOS 27),
    # plus /dev/kvm via nested virtualization (so nixos-test still works).
    # No QEMU, so the M5 gic-version workaround is not needed.
    # The Determinate module wires up the launchd daemon, the ssh_config.d
    # alias and the /etc/nix/machines entry itself (nix-darwin's own
    # nix.linux-builder would require nix.enable = true).
    nixosVmBasedLinuxBuilder = {
      enable = true;
      hostName = "linux-builder";
      package = pkgs.darwin.linux-builder-vz;
      # The guest's root filesystem is an implicit-size tmpfs: 50% of VM RAM.
      # At the 3G default that's 1.5G, which podman's Go link step blows
      # through ("No space left on device" during the ld.bfd final link).
      # 8G RAM -> 4G tmpfs, with headroom for memory-hungry Go builds.
      config = {
        virtualisation.darwin-builder.memorySize = 8 * 1024;
      };
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
    };
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
