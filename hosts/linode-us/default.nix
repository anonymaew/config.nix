# linode-us — Linode VPS (45.33.39.244)
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

  # Fresh install at release 26.11 — set the state version to the release of
  # the first switch of this system (nixpkgs-unstable ≈ 26.11). Don't bump it
  # on existing systems; only new installs get to pick the current release.
  system.stateVersion = "26.11";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-generations +8";
  nix.optimise.automatic = true;
  nix.settings.trusted-users = [
    "root"
    "napatsc"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "builder:qPTpfl43MdQlIoXVLCvA0/II/esC9F2qhau7skLyV5Y="
  ];

  # Linode boots by reading /boot/grub/grub.cfg from the root filesystem
  # (partitionless ext4 — the guest MBR is never executed, so GRUB must not
  # install to a device). See docs/install-nixos-on-linode.md.
  # hardware-configuration.nix sets boot.loader.grub.device = "nodev"
  # (menu-only, no MBR write); keep the bootloader regenerating so every
  # deployed generation stays bootable.
  boot.loader.grub.enable = true;
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,19200n8" # Linode Lish/Glish serial console (19200 baud)
  ];

  networking.hostName = "linode-us"; # Define your hostname.
  # Linode images/custom-boot run with net.ifnames=0; keep eth0 naming and
  # DHCP (Linode leases the same address to the same MAC).
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.enableIPv6 = true;

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

  # Define a user account — mirrors hetzner-sg.
  users.users = {
    "${config.user.username}" = {
      isNormalUser = true;
      linger = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDe/pgCTH3B4AzKAVMcA2l42jJq2K4tiObkLNsvbrJZG napatsc@macair"
      ];
    };
    # Root key auth is the operational/rescue path (deploy-rs connects as
    # root; the box's ~/.ssh is state, so declaring it here keeps it
    # reproducible across switches).
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDe/pgCTH3B4AzKAVMcA2l42jJq2K4tiObkLNsvbrJZG napatsc@macair"
    ];
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
  ];

  # OpenSSH hardening: key-only auth. hetzner-sg moves SSH to port 2222; this
  # host stays on 22 since the firewall already drops everything but SSH.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Tailscale — join the existing tailnet (homelab is already on it; hetzner
  # has it commented out). First login is interactive: run `tailscale up` on
  # the box and approve the printed URL with your Tailscale account.
  services.tailscale.enable = true;

  # ── Public ingress proxy (kernel nftables DNAT, no userspace daemon) ──
  # Internet → linode :80/:443 → tailnet → homelab traefik NodePorts.
  # TLS stays end-to-end (traefik + cert-manager terminate inside the cluster).
  # Trade-off: homelab sees every client as linode's tailnet IP (100.84.229.73) —
  # real client IPs would need a userspace PROXY-protocol proxy (nginx/haproxy).
  networking.nftables.enable = true; # switches the firewall backend to nftables
  networking.nftables.tables.nat = {
    family = "ip";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "eth0" tcp dport 80  dnat to 100.89.132.36:31557 # traefik http NodePort
        iifname "eth0" tcp dport 443 dnat to 100.89.132.36:32724 # traefik https NodePort
        iifname "eth0" udp dport 443 dnat to 100.89.132.36:31999 # QUIC/HTTP3 (traefik-udp)
      }
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "tailscale0" masquerade # return path via the tailnet
      }
    '';
  };
  # nftables doesn't enable forwarding itself (networking.nat would, but its
  # DNAT-in and masquerade-out are tied to ONE interface — ours are asymmetric:
  # in on eth0, return out on tailscale0 — hence the custom table above).
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
  boot.kernel.sysctl."net.ipv4.conf.default.forwarding" = true;

  # Firewall enabled by default; the openssh module opens 22, drop the rest.
  networking.firewall.enable = true;
  # Tailscale direct connections: inbound UDP 41641 (relay via DERP works
  # without it — this just improves p2p connectivity).
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    41641
    443
  ];
}
