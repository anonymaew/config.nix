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
  environment.systemPackages = with pkgs; [
    # bun
    alejandra
    prettierd

    bat
    btop
    coreutils
    dasel
    direnv
    # entr
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
    # watch
    wget
    yt-dlp

    ollama
  ];

  # TBD
  homebrew = {
    enable = true;
    onActivation = {
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
      "localsend"
      "macfuse"
      "nikitabobko/tap/aerospace"
      "steam"
      "stolendata-mpv"
      "whisky"
      "wireshark"
      "zen"
      "zoom"
      "zotero"
    ];
  };

  # system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;
}
