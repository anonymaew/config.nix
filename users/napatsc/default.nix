{
  config,
  pkgs,
  ...
}:
{
  home = {
    username = "napatsc";
    homeDirectory = "/Users/napatsc";
    stateVersion = "26.05";
  };

  xdg.enable = true;

  home.packages = with pkgs; [
    # CLI tools
    ansible
    bun
    go
    nodejs_latest
    pandoc
    php
    phpstan
    php84Packages.composer
    rustup
    typst
    uv
    btop
    curlFull
    docker-compose
    eza
    fastfetch
    ffmpeg
    fzf
    imagemagick
    inetutils
    just
    kubectl
    kubernetes-helm
    lazygit
    libreoffice-bin
    parallel
    podman
    rsync
    smartmontools
    uutils-coreutils-noprefix
    wget
    wireguard-tools
    yt-dlp
    android-tools

    # Fonts
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts

    # GUI apps via brew-nix
    aerospace
    brewCasks.audacity
    brewCasks.bitwarden
    brewCasks.gimp
    brewCasks.helium-browser
    inkscape
    localsend
    brewCasks.markdown-preview
    mpv-unwrapped
    brewCasks.obs
    brewCasks.stats
    steam-unwrapped
    # brewCasks.tailscale-app

    brewCasks.slack
    brewCasks.zen
    zoom-us
    # zotero
  ];

  # SMB mount for k3s network storage (SMB NodePort 30445 → pod port 445).
  # Mounted at ~/.mnt/code-stash — a hidden, purpose-built mount root. NOT
  # inside ~/code (repo scans/editors never recurse into it) and invisible to
  # dotfile-respecting tools (rg/fd skip hidden by default). Nothing enumerates,
  # cleans, or backs it up — unlike /Volumes (root-owned), ~/Documents
  # (iCloud/Spotlight/app dialogs), or the XDG dirs (app namespaces).
  # User-writable, so no root daemon is needed; optionally add to Finder sidebar.
  # Credentials: user `samba`, password in secrets/homelab.yaml (smb-password).
  # sops-nix decrypts it to ~/.config/sops-nix/secrets/smb-password (no
  # keychain dependency — the keychain item vanished once and broke the mount).
  # NOTE: mount_smbfs -N does NOT consult the keychain on this macOS, so the
  # script fetches the password itself and injects it into the URL.
  #
  # Reconnect fallback: the agent runs a CONTINUOUS polling loop (KeepAlive =
  # true keeps the process alive), so a mount lost later to sleep/wake, a
  # Tailscale path change, or an homelab/k3s restart is re-established on its
  # own — not just retried once at login the way a one-shot retry loop would.
  # Logs only on state transitions, so a long disconnect doesn't spam the log.
  launchd.agents.smb-code-stash = {
    enable = true;
    config = {
      Label = "com.napatsc.smb-code-stash";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          mountpoint="${config.home.homeDirectory}/.mnt/code-stash"
          secret="${config.home.homeDirectory}/.config/sops-nix/secrets/smb-password"
          log="/tmp/smb-code-stash.log"
          mkdir -p "$mountpoint"
          last_state=""
          while :; do
            if mount | grep -q "$mountpoint"; then
              if [ "$last_state" != "up" ]; then
                echo "$(date +%F_%T) mount UP" >> "$log"
                last_state=up
              fi
            else
              pw="$(/bin/cat "$secret" 2>/dev/null | /usr/bin/tr -d "\n")"
              if [ -n "$pw" ] && /sbin/mount_smbfs "//samba:''${pw}@homelab:30445/code-stash" "$mountpoint"; then
                if [ "$last_state" != "up" ]; then
                  echo "$(date +%F_%T) mounted" >> "$log"
                  last_state=up
                fi
              else
                if [ "$last_state" != "down" ]; then
                  echo "$(date +%F_%T) homelab unreachable, retrying..." >> "$log"
                  last_state=down
                fi
              fi
            fi
            sleep 30
          done
        ''
      ];
      RunAtLoad = true;
      # Keep the watchdog process alive so it can remount after a later
      # disconnect (a one-shot retry loop would only win the race once).
      KeepAlive = true;
      StandardOutPath = "/tmp/smb-code-stash.log";
      StandardErrorPath = "/tmp/smb-code-stash.log";
    };
  };

  sops.secrets.smb-password = {
    sopsFile = ../../secrets/homelab.yaml;
  };

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
