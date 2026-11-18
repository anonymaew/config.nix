# linode-us — Linode VPS (45.33.39.244)
{
  user,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Fresh install at release 26.11 — set the state version to the release of
  # the first switch of this system (nixpkgs-unstable ≈ 26.11). Don't bump it
  # on existing systems; only new installs get to pick the current release.
  system.stateVersion = "26.11";
  # Nix settings, GC, locale, timezone and the baseline package set come from
  # `config.nixos.modules.base` (modules/nixos-base.nix).

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

  # Time zone / locale are provided by `config.nixos.modules.base`.

  # Define a user account — mirrors hetzner-sg. `isNormalUser`, the wheel group
  # and the user's authorized key come from `config.nixos.modules.identity`;
  # this host adds lingering user services.
  users.users.${user.username} = {
    linger = true;
  };
  # Root key auth is the operational/rescue path (deploy-rs connects as
  # root; the box's ~/.ssh is state, so declaring it here keeps it
  # reproducible across switches).
  users.users.root.openssh.authorizedKeys.keys = [ user.sshKey ];

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

  # Tailscale — join the existing tailnet (homelab-n150 is already on it).
  # First login is interactive: run `tailscale up` on the box and approve the
  # printed URL with your Tailscale account.
  services.tailscale.enable = true;

  # ── Public ingress proxy (kernel nftables DNAT, no userspace daemon) ──
  # Internet → linode :80/:443 → tailnet → homelab-n150 edge-gateway NodePorts.
  # TLS stays end-to-end (agentgateway terminates it inside the cluster, using
  # the cert-manager wildcard).
  #
  # ⚠️ The NodePorts below are pinned on the cluster side, not assigned
  # dynamically: `AgentgatewayParameters/edge` in homelab-helm sets
  #   port 80  -> nodePort 31557
  #   port 443 -> nodePort 32724
  # If that pin is removed, Kubernetes picks new numbers, this DNAT keeps
  # forwarding to the old ones, and every *.napatsc.com host dies while
  # *.napatsc.net (LAN address) keeps working — which looks like a DNS fault.
  #
  # Trade-off: homelab-n150 sees every client as linode's tailnet IP
  # (100.84.229.73) — real client IPs would need a userspace PROXY-protocol
  # proxy (nginx/haproxy).
  networking.nftables.enable = true; # switches the firewall backend to nftables
  networking.nftables.tables.nat = {
    family = "ip";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "eth0" tcp dport 80  dnat to 100.89.132.36:31557 # edge-gateway http NodePort
        iifname "eth0" tcp dport 443 dnat to 100.89.132.36:32724 # edge-gateway https NodePort
        # No QUIC/HTTP3 rule: Traefik's udp 443 -> :31999 forward went away with
        # Traefik, and agentgateway has no QUIC listener at all.
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
  # UDP 443 was opened only for the HTTP/3 route and is no longer needed.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    41641
  ];
}
