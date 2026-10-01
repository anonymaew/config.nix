{
  config,
  pkgs,
  lib,
  ...
}:
let
  # ── Linux builder idle policy knobs ──────────────────────────────
  # Port the builder VM listens on (vzvm forwards 127.0.0.1:31022 -> guest:22).
  builderPort = 31022;
  # Stop the VM after this many minutes without any client connection.
  idleMinutes = 15;
  # How often the idle-stop watchdog ticks.
  tickSeconds = 5 * 60;
in
{
  # ── Hostname ─────────────────────────────────────────────────────
  # Pins the kernel hostname (runs `scutil --set HostName` on switch).
  # Without this, macOS leaves HostName unset and derives the hostname from
  # the network's reverse-DNS (e.g. eduroam-bowers-128-114-155-46.ucsc.edu)
  # whenever eduroam DHCP hands out a lease.
  networking.hostName = "macair";
  networking.localHostName = "macair"; # Bonjour .local name (defaults to hostName anyway)
  networking.computerName = "macair"; # user-facing name in Sharing pane

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
        # 8 guest vCPUs to match maxJobs = 8 below. The VM's cpuCount comes
        # from the generic `virtualisation.cores` option (vz-vm.nix:
        # `cpuCount = cfg.cores`) — NOT from darwin-builder.*, which has no
        # cores option. The default is 1, so Linux builds used to queue up
        # on a single guest vCPU.
        virtualisation.cores = 8;
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

  # ── Linux builder idle policy ────────────────────────────────────
  # The VM above otherwise runs 24/7: determinate's daemon hardcodes
  # KeepAlive = true + RunAtLoad = true, pinning 8 vCPUs + 8 GiB RAM even
  # when nothing builds. Two pieces stop it after `idleMinutes` and bring
  # it back on demand:
  #
  # 1. `org.nixos.linux-builder-idle-stop` — a launchd timer (tick every
  #    `tickSeconds`) watching port 31022 for ESTABLISHED connections. After
  #    `idleMinutes` with none it UNLOADS the builder daemon
  #    (`launchctl bootout system/org.nixos.linux-builder`), stopping the VM
  #    and freeing its RAM. Unloading rather than killing matters:
  #    KeepAlive = true would otherwise respawn the VM instantly.
  #
  # 2. On-demand restart — the ssh config.d alias gets a ProxyCommand
  #    (`/etc/nix/linux-builder-proxy.sh`) that re-bootstraps the daemon
  #    (`launchctl bootstrap system <plist>`, RunAtLoad fires) when a build
  #    arrives while the VM is down, then forwards to port 31022. nix-daemon
  #    spawns its ssh as root, so the proxy can manage the system launchd
  #    domain without sudo prompts. vzvm holds the vsock forward until the
  #    guest's sshd is up ("vsock:22 not ready. holding connection...").
  #    Trade-off: the first Linux build after idle pays a ~30-60s cold boot.
  launchd.daemons.linux-builder-idle-stop = {
    script = ''
      export PATH=/usr/bin:/bin:/usr/sbin:/sbin
      state=/var/lib/linux-builder/.idle-since
      if /usr/sbin/lsof -nP -iTCP:${toString builderPort} -sTCP:ESTABLISHED >/dev/null 2>&1; then
        : > "$state" # a build is (or was very recently) connected: re-arm the clock
      elif [ -f "$state" ]; then
        age=$(( $(/bin/date +%s) - $(/bin/stat -f %m "$state") ))
        if [ "$age" -ge $((idleMinutes * 60)) ]; then
          /bin/launchctl bootout system/org.nixos.linux-builder 2>/dev/null || true
          /bin/rm -f "$state"
        fi
      else
        : > "$state" # VM up but idle: start the clock
      fi
    '';
    serviceConfig = {
      StartInterval = tickSeconds;
    };
  };

  # On-demand cold start + forwarder for the NixOS Linux builder VM. Runs as
  # root (spawned by nix-daemon's ssh): re-bootstraps the idle-stopped
  # launchd daemon (RunAtLoad fires -> VM boots), waits for the vsock forward
  # to listen, then hands the connection to vzvm, which holds it until the
  # guest sshd is up.
  # nix-darwin's environment.etc has no `mode` option (only source/text), so
  # point it at an executable store path from pkgs.writeShellScript.
  environment.etc."nix/linux-builder-proxy.sh".source = pkgs.writeShellScript "linux-builder-proxy" ''
    set -u
    port=${toString builderPort}
    plist=/Library/LaunchDaemons/org.nixos.linux-builder.plist
    nc=/usr/bin/nc
    if ! $nc -z -w 1 127.0.0.1 "$port" 2>/dev/null; then
      /bin/launchctl bootstrap system "$plist" 2>/dev/null || true
      i=0
      while [ $i -lt 180 ]; do
        $nc -z -w 1 127.0.0.1 "$port" 2>/dev/null && break
        i=$((i + 1))
        /bin/sleep 1
      done
    fi
    exec $nc 127.0.0.1 "$port"
  '';

  # The determinate module also writes this file (without ProxyCommand);
  # override it so a cold start happens transparently on the next build.
  environment.etc."ssh/ssh_config.d/100-linux-builder.conf".text = lib.mkForce ''
    Host linux-builder
      User builder
      Hostname localhost
      HostKeyAlias linux-builder
      Port ${toString builderPort}
      IdentityFile /etc/nix/builder_ed25519
      ProxyCommand /etc/nix/linux-builder-proxy.sh %h %p
  '';

  # ── Linux builder workaround ────────────────────────────────────
  # nix-darwin's own `nix.linux-builder` module (inactive here, since
  # nix.enable = false) still emits `rm -rf /var/lib/linux-builder` from
  # its disabled branch. Both it and determinate's `nixosVmBasedLinuxBuilder`
  # target the same `system.activationScripts.preActivation.text` (lines
  # type → concatenated), so `mkdir` runs before the `rm -rf` and the
  # builder dir never survives a switch. launchd then refuses to spawn
  # org.nixos.linux-builder (cwd /var/lib/linux-builder missing, exit 78)
  # and all x86_64 remote builds die with "Failed to find a machine for
  # remote build!". Re-create the dir at the end of preActivation, before
  # the launchd section (postActivation is too late: launchd loads the
  # daemon first and fails the first spawn).
  system.activationScripts.preActivation.text = lib.mkAfter ''
    mkdir -p /var/lib/linux-builder
  '';

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

  # ── macOS System Settings ─────────────────────────────────────────
  # Everything that used to be declared as `system.defaults` here (dock, dark
  # mode, 24-hour time, key repeat, trackpad speed, menu bar, Fn key, metric
  # units, battery percentage, hot corners) moved to hosts/macair/mac.nix,
  # which declares it through nix-plist-manager (home-manager/user scope) so
  # there is a single writer for those plists. The old-key -> new-option map is
  # in that file's header.
  system = {
    stateVersion = 7;

    # Not covered by nix-plist-manager: caps lock -> escape and the keyboard
    # mapping activation, so these stay in nix-darwin.
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };
}
