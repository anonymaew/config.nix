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

  # SMB mount for k3s network storage (SMB NodePort 30445 → pod port 445)
  # First time: mount manually with password to save to keychain:
  #   mkdir -p ~/code/code-stash
  #   mount -t smbfs //samba:YOUR_PASSWORD@homelab:30445/code-stash ~/code/code-stash
  # After that, this agent auto-mounts on login (password from keychain).
  launchd.agents.smb-code-stash = {
    enable = true;
    config = {
      Label = "com.napatsc.smb-code-stash";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          mountpoint="${config.home.homeDirectory}/code/code-stash"
          mkdir -p "$mountpoint"
          if ! mount | grep -q "$mountpoint"; then
            /sbin/mount_smbfs -N //samba@homelab:30445/code-stash "$mountpoint"
          fi
        ''
      ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/smb-code-stash.log";
      StandardErrorPath = "/tmp/smb-code-stash.log";
    };
  };

  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
