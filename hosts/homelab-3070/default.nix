# homelab-3070 — desktop-class box (i7-7700K / GTX 3070 / 3.8 GB RAM)
#
# Second k3s node: an agent/worker joined to the homelab-n150 server. The
# install itself was done by nixos-anywhere (disko + ./disk-config.nix); see
# docs/install-nixos-on-homelab-3070.md.
{
  user,
  lib,
  config,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  # First switch of this box is the 26.11 release; never bump it later.
  system.stateVersion = "26.11";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab-3070";
  networking.enableIPv6 = true;

  # Building on this box is memory-constrained (installer/builder pushes).
  nix.settings.builders-use-substitutes = lib.mkForce false;

  # ── Secrets ────────────────────────────────────────────────────────
  # The k3s join token only. Encrypted to the admin key and to this box's
  # own host key (see .sops.yaml); no other secret is needed on a worker.
  sops = {
    defaultSopsFile = ../../secrets + "/homelab-3070.yaml";
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.generateKey = true;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
  sops.secrets.k3s-token = { };

  users.users.${user.username}.linger = true;
  # Root key auth is what deploy-rs uses; it is state otherwise.
  users.users.root.openssh.authorizedKeys.keys = [ user.sshKey ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # First login is interactive: `tailscale up`, approve the printed URL.
  services.tailscale.enable = true;

  # ── k3s agent ──────────────────────────────────────────────────────
  # The server is homelab-n150 (k8s node name `homelab`) at the stable
  # tailnet IP; pods and flannel ride the tailnet like they do on the server.
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://100.89.132.36:6443";
    tokenFile = config.sops.secrets.k3s-token.path;
    extraFlags = [
      "--node-name=homelab-3070"
      "--node-ip=100.83.20.73" # tailnet IP (stable per node key)
      "--node-external-ip=100.83.20.73"
      "--flannel-iface=tailscale0"
      # NEVER storage-tier=large: `local-large` PVs must stay on the N150 HDD.
      "--node-label=storage-tier=nvme"
    ];
  };
  systemd.services.k3s.after = [
    "tailscaled.service"
    "sops-install-secrets.service"
  ];
  systemd.services.k3s.wants = [ "tailscaled.service" ];

  networking.firewall = {
    # Same exposure as homelab-n150.
    allowedTCPPorts = [
      22 # sshd (deploy-rs)
      9100 # node-exporter
      10250 # kubelet
    ];
    allowedUDPPorts = [
      8472 # flannel VXLAN
      41641 # tailscale direct
    ];
    interfaces.tailscale0 = {
      allowedTCPPorts = [
        31557 # traefik http NodePort
        32724 # traefik https NodePort
      ];
      allowedUDPPorts = [
        31999 # traefik QUIC NodePort
      ];
    };
  };

  # local-path-provisioner writes PVC data under /var/lib/rancher/k3s/storage.
  systemd.services."k3s-storage-dirs" = {
    description = "Ensure k3s local-path storage directory exists";
    serviceConfig.Type = "oneshot";
    script = "mkdir -p /var/lib/rancher/k3s/storage";
    wantedBy = [ "multi-user.target" ];
  };
}
