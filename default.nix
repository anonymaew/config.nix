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

    brewCasks."alacritty"
    brewCasks.audacity
    brewCasks."android-platform-tools"
    brewCasks."bitwarden"
    brewCasks."blender"
    brewCasks."db-browser-for-sqlite"
    brewCasks."eloston-chromium"
    brewCasks."firefox"
    brewCasks."ghostty"
    brewCasks."gimp"
    brewCasks."inkscape"
    brewCasks."jellyfin-media-player"
    brewCasks."josm"
    brewCasks."localsend"
    brewCasks."whisky"
    brewCasks."zen"
    brewCasks."zotero"

    aerospace
    jankyborders
    mpv-unwrapped
    steam-unwrapped
    vfkit
    wireshark
    zoom-us
  ];
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "steam-unwrapped"
      "zoom"
    ];
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 4;
}
