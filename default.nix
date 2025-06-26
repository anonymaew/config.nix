{
  pkgs,
  vars,
  lib,
  ...
}: {
  imports = import ./programs/darwin-default.nix;
  users.users.${vars.name} = {
    name = "${vars.name}";
    home = "/Users/${vars.name}";
    shell = pkgs.zsh;
  };

  # services.nix-daemon.enable = true;
  nix = {
    enable = true;
    package = pkgs.nix;
    settings = {
      "extra-experimental-features" = ["nix-command" "flakes"];
    };
  };
  ids.gids.nixbld = 350;

  programs = {
    gnupg.agent.enable = true;
    zsh.enable = true;
  };

  system.primaryUser = vars.name;

  brew-nix.enable = true;
  environment.systemPackages = with pkgs; [
    alejandra
    prettierd

    bat
    btop
    dasel
    direnv
    eza
    fastfetch
    ffmpeg-full
    fzf
    gnupg
    ifstat-legacy
    imagemagick
    inetutils
    just
    kubectl
    lazydocker
    lazygit
    libreoffice-bin
    moreutils
    ncurses
    nix-search-tv
    pandoc
    parallel
    podman
    podman-compose
    rsync
    smartmontools
    speedtest-cli
    uutils-coreutils-noprefix
    wget
    wireguard-tools
    yt-dlp

    ollama

    audacity
    brewCasks.android-platform-tools
    bitwarden-desktop
    blender
    # brewCasks.eloston-chromium
    firefox
    # brewCasks.ghostty
    gimp
    inkscape
    jellyfin-media-player
    josm
    localsend
    qbittorrent
    utm
    sqlitebrowser
    brewCasks.zen
    zotero

    aerospace
    jankyborders
    mpv-unwrapped
    steam-unwrapped
    vfkit
    wireshark
    zoom-us
  ];
  nixpkgs.config = {
    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "steam-unwrapped"
        "zoom"
      ];
    allowBroken = true;
  };

  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts
  ];

  # system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;
}
