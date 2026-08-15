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
    steam-unwrapped
    # brewCasks.tailscale-app

    brewCasks.slack
    brewCasks.zen
    zoom-us
    zotero
  ];

  # SMB mount for k3s network storage (SMB NodePort 30445 → pod port 445).
  # Mounted at ~/.mnt/code-stash — a hidden, purpose-built mount root. NOT
  # inside ~/code (repo scans/editors never recurse into it) and invisible to
  # dotfile-respecting tools (rg/fd skip hidden by default). Nothing enumerates,
  # cleans, or backs it up — unlike /Volumes (root-owned), ~/Documents
  # (iCloud/Spotlight/app dialogs), or the XDG dirs (app namespaces).
  # User-writable, so no root daemon is needed; optionally add to Finder sidebar.
  # Credentials: user `samba`, password in the login keychain
  # (server=homelab, account=samba, protocol=smb). Store/update it with:
  #   security add-internet-password -a samba -s homelab -r 'smb ' -w '<password>' -T /usr/bin/security
  # NOTE: mount_smbfs -N does NOT consult the keychain on this macOS, so the
  # script fetches the password itself and injects it into the URL. The retry
  # loop + KeepAlive cover the login-before-VPN/keychain-unlock case.
  launchd.agents.smb-code-stash = {
    enable = true;
    config = {
      Label = "com.napatsc.smb-code-stash";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          mountpoint="${config.home.homeDirectory}/.mnt/code-stash"
          mkdir -p "$mountpoint"
          i=0
          while [ "$i" -lt 30 ]; do
            if mount | grep -q "$mountpoint"; then
              exit 0
            fi
            pw="$(/usr/bin/security find-internet-password -s homelab -a samba -w 2>/dev/null | /usr/bin/tr -d "\n")"
            if [ -n "$pw" ] && /sbin/mount_smbfs "//samba:''${pw}@homelab:30445/code-stash" "$mountpoint"; then
              exit 0
            fi
            i=$((i + 1))
            sleep 10
          done
          exit 1
        ''
      ];
      RunAtLoad = true;
      # Restart on failure (e.g. network/VPN not up yet at login).
      KeepAlive = {
        SuccessfulExit = false;
      };
      StandardOutPath = "/tmp/smb-code-stash.log";
      StandardErrorPath = "/tmp/smb-code-stash.log";
    };
  };

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
