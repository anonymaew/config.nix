# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/identity.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets + "/homelab.yaml";
    defaultSopsFormat = "yaml";
    # No per-box secrets anymore — k3s-token/wireguard were dropped when the
    # cluster moved onto this box (smb-password is consumed on macair only).
    # Machine-side decryption: convert SSH host key to age key
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.generateKey = true;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-generations +8";
  nix.optimise.automatic = true;
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "builder:qPTpfl43MdQlIoXVLCvA0/II/esC9F2qhau7skLyV5Y="
  ];
  nix.settings.trusted-users = [
    "root"
    "napatsc"
  ];
  # Disable substituting during cross-build from darwin (cache resolution can fail)
  nix.settings.builders-use-substitutes = lib.mkForce false;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab"; # Define your hostname.
  # Enables wireless support via wpa_supplicant.

  # networking.wireless = {
  #   enable = true;
  #   networks = {
  #     "SundingBrothers".psk = "ipaidforinternetservice";
  #   };
  # };
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 443;
  };
  networking.enableIPv6 = true;

  # WireGuard removed — k3s is now a standalone server on this box; the only
  # overlay left is Tailscale (linode proxies public ingress over it).

  # systemd.user.services = {
  #   "podman.socket".enable = true;
  #   "podman-restart.service".enable = true;
  # ExecStart=/nix/store/a6afd7k1i8036rsdrf1dnj7pylg27pzb-podman-5.6.1/bin/podman $LOGGING start --all --filter restart-policy=always
  # ExecStop=/nix/store/a6afd7k1i8036rsdrf1dnj7pylg27pzb-podman-5.6.1/bin/podman  $LOGGING stop  --all --filter restart-policy=always

  # };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  # networking.networkmanager.enable = true;

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

  # # Enable the X11 windowing system.
  # services.xserver = {
  #   enable = false;
  #   # Enable the GNOME Desktop Environment.
  #   displayManager.gdm.enable = true;
  #   desktopManager.gnome.enable = true;
  #   # Configure keymap in X11
  #   xkb = {
  #     layout = "us";
  #     variant = "";
  #   };
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with pipewire.
  # services.pulseaudio.enable = false;
  # security.rtkit.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  #   # If you want to use JACK applications, uncomment this
  #   #jack.enable = true;
  #
  #   # use the example session manager (no others are packaged yet so this is enabled by default,
  #   # no need to redefine it in your config for now)
  #   #audio-session.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users = {
    "${config.user.username}" = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "podman"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDe/pgCTH3B4AzKAVMcA2l42jJq2K4tiObkLNsvbrJZG napatsc@macair"
      ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    btop
    direnv
    eza
    fastfetch
    ffmpeg-full
    fzf
    gcc
    git
    gnused
    imagemagick
    inetutils
    just
    less
    ncurses
    neovim
    pandoc
    parallel
    ripgrep
    rsync
    tmux
    uutils-coreutils-noprefix
    wget
    # yt-dlp
  ];

  virtualisation = {
    containers = {
      enable = true;
    };
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      extraPackages = with pkgs; [ docker-compose ];
      autoPrune.enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # k3s — standalone single-node server (hetzner decommissioned).
  # Node IP moves 10.0.0.2 → 100.89.132.36 once: pod re-IPs + one flannel
  # re-subnet expected; services/NodePorts (0.0.0.0-bind) unaffected. API
  # reachable over the tailnet at https://homelab:6443 or https://100.89.132.36:6443.
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true; # harmless on an already-initialized etcd
    extraFlags = [
      "--disable=traefik" # installed via helm (homelab-helm), not the bundled chart
      "--disable=local-storage" # replaced by our standalone provisioner in homelab-helm
      "--disable-network-policy" # k3s#12639: netpol init hits "failed to find interface with specified node ip"
                              # (node IP pinned to P2P tailscale0), causing a shutdown/restart loop
      "--node-external-ip=100.89.132.36" # advertise the (stable) tailnet IP
      "--node-ip=100.89.132.36" # pin kubelet to the tailnet IP (wg-client is gone)
      "--flannel-iface=tailscale0" # pod network rides the tailnet overlay
      "--tls-san=homelab"
      "--tls-san=100.89.132.36"
      "--node-label=storage-tier=large"
      "--etcd-snapshot-schedule-cron='0 */6 * * *'" # hardening: this is now THE etcd
    ];
  };

  # Ensure /mnt/fast exists for local-path-provisioner (fast/NVMe tier)
  systemd.services."k3s-storage-dirs" = {
    description = "Ensure k3s local-path-provisioner mount points exist";
    serviceConfig.Type = "oneshot";
    script = "mkdir -p /mnt/fast /mnt/hdd/k3s-storage";
    wantedBy = [ "multi-user.target" ];
  };

  # Some programs need SUID wrappers, can be configured further, or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  security.pam.sshAgentAuth.enable = true;

  services.tailscale.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    6443 # k8s API
    9100 # node-exporter (node metrics)
    10250 # kubelet (metrics, kubectl logs/exec)
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # k3s, flannel
  ];
  # Ingress NodePorts reachable only from the tailnet (linode DNATs 80/443 to
  # these; public can't reach homelab directly — it's NAT'd behind a home router).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    31557 # traefik http NodePort
    32724 # traefik https NodePort
  ];
  networking.firewall.interfaces.tailscale0.allowedUDPPorts = [
    31999 # traefik udp/QUIC NodePort
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
