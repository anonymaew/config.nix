# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.05";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.hostName = "hetzner-sg"; # Define your hostname.

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.ip_unprivileged_port_start" = 80;
  };
  networking.enableIPv6 = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [ 51820 ];
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
      enable = true;
      registries.search = [ "docker.io" ];
    };
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      extraPackages = with pkgs; [ podman-compose ];
      autoPrune.enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
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
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
