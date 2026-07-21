# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  vars,
  secrets-dir,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  sops = {
    defaultSopsFile = secrets-dir + "/hetzner.yaml";
    defaultSopsFormat = "yaml";
    secrets.wireguard-server-private-key = {
      owner = vars.name;
      path = "/etc/wireguard/server.key";
    };
    # Build-time decryption key (local age key)
    age.keyFile = "/Users/napatsc/.config/sops/age/keys.txt";
    # Machine-side decryption: convert SSH host key to age key
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.generateKey = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [ "root" "napatsc" ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "builder:qPTpfl43MdQlIoXVLCvA0/II/esC9F2qhau7skLyV5Y="
  ];
  networking.hostName = "hetzner-sg"; # Define your hostname.

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.ip_unprivileged_port_start" = 80;
  };
  networking.enableIPv6 = true;
  networking.wireguard.interfaces = {
    "wg-server" = {
      ips = [ "10.0.0.1/24" ];
      privateKeyFile = config.sops.secrets.wireguard-server-private-key.path;
      listenPort = 51820;
      peers = [
        {
          publicKey = "73lxEoHgR6yO6KjyaX5bAtxh34u5QRna1T4x+sbE6AQ=";
          allowedIPs = [ "10.0.0.2/32" ];
        }
      ];
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      6443 # k3s API
      2379 # k3s, etcd clients
      2380 # k3s, etcd peers
    ];
    allowedUDPPorts = [
      443
      8472 # k3s, flannel
      51820
    ];
  };
  # networking.wg-quick.interfaces.server = {
  #   autostart = true;
  #   configFile = "/home/napatsc/server.conf";
  # };

  # Set your time zone.
  time.timeZone = "Asia/Bangkok";

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    "${vars.name}" = {
      isNormalUser = true;
      linger = true;
      extraGroups = [ "wheel" ];
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
    inetutils
    neovim
    uutils-coreutils-noprefix
    wget
    wireguard-tools
  ];

  virtualisation = {
    containers = {
      # enable = true;
      registries.search = [ "docker.io" ];
    };
    oci-containers.backend = "podman";
    podman = {
      # enable = true;
      extraPackages = with pkgs; [ podman-compose ];
      autoPrune.enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = [
      "--node-external-ip=5.223.55.249"
      "--advertise-address=10.0.0.1"
      "--flannel-iface=wg-server"
      "--disable=traefik"
      "--disable=local-storage" # replaced by our standalone provisioner in homelab-helm
    ];
  };

  # Ensure /mnt/fast exists for local-path-provisioner (fast/NVMe tier)
  systemd.services."k3s-storage-dirs" = {
    description = "Ensure k3s local-path-provisioner mount points exist";
    serviceConfig.Type = "oneshot";
    script = "mkdir -p /mnt/fast";
    wantedBy = [ "multi-user.target" ];
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    settings = {
      PasswordAuthentication = false;
    };
  };

  # services.tailscale.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
