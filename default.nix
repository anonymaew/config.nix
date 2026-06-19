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
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      use-xdg-base-directories = true;
    };
     gc = {
       automatic = true;
       options = "--delete-generations +8";
     };
     optimise.automatic = true;
     settings.auto-optimise-store = true;
  };

  brew-nix.enable = true;
  environment.systemPackages = with pkgs; [
    bun
    pandoc
    rustup
    typst
    uv

    btop
    container
		curlFull
    # dasel
    # direnv
    docker-compose
    eza
    fastfetch
    # ffmpeg-full
    fzf
    git
    imagemagick
    inetutils
    just
    kubectl
		kubernetes-helm
    lazygit
    less
    libreoffice-bin
    ncurses
    parallel
    podman
    rsync
    smartmontools
    uutils-coreutils-noprefix
    wget
    wireguard-tools
    yt-dlp

    # ollama
		pi-coding-agent

    audacity
    android-tools
    bitwarden-desktop
    # brewCasks.blender
		# brewCasks.cap
		brewCasks.cmux
    brewCasks.gimp
    brewCasks.helium-browser
    brewCasks.inkscape
    localsend
		brewCasks.obs
    # tailscale-gui
		# recordly
		# brewCasks.tailscale-app
    brewCasks.zen
    zotero

    aerospace
    jankyborders
    mpv-unwrapped
    steam-unwrapped
    vfkit
    zoom-us
  ];
  nixpkgs.config = {
    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "steam-unwrapped"
        "zoom"
      ];
  };

  fonts.packages = with pkgs; [
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts
  ];
}
