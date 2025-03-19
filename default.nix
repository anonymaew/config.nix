{ pkgs, vars, lib, ... }: {
  imports = (import ./programs/darwin-default.nix);
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
      "extra-experimental-features" = [ "nix-command" "flakes" ];
    };
  };
  ids.gids.nixbld = 350;

  programs = {
    gnupg.agent.enable = true;
    zsh.enable = true;
  };

  environment.systemPackages = with pkgs; [
    act
    bun
    docker
    go
    hugo
    # nodejs_22
    # prettierd
    # python3
    rustup
    typst
    xq-xml
    # darwin.xcode

    bat
    btop
    coreutils
    dasel
    direnv
    entr
    eza
    fastfetch
    ffmpeg-full
    fzf
    gnupg
    ifstat-legacy
    imagemagick
    inetutils
    just
    lazydocker
    lazygit
    libreoffice-bin
    pandoc
    parallel
    podman
    podman-compose
    rsync
    smartmontools
    speedtest-cli
    texliveFull
    watch
    # wireguard-tools
    wget
    yt-dlp

    ollama
  ];

  homebrew =
    {
      enable = true;
      onActivation =
        {
          autoUpdate = true;
          cleanup = "uninstall";
          upgrade = true;
        };
      taps = [
        "cfergeau/crc"
        "FelixKratz/formulae"
      ];
      brews = [
        "borders"
        "vfkit"
      ];
      casks = [
        "alacritty"
        "android-platform-tools"
        "audacity"
        "bitwarden"
        "blender"
        "db-browser-for-sqlite"
        "eloston-chromium"
        "firefox"
        "font-jetbrains-mono-nerd-font"
        "gimp"
        "jellyfin-media-player"
        "josm"
        "libreoffice"
        {
          name = "librewolf";
          args = { no_quarantine = true; };
        }
        "localsend"
        "macfuse"
        "nikitabobko/tap/aerospace"
        "steam"
        "stolendata-mpv"
        "whisky"
        "wireshark"
        "zen-browser"
        "zoom"
        "zotero"
      ];
    };

  # system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;
}

