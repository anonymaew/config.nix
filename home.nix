{
  config,
  pkgs,
  ...
}: {
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
    ffmpeg-full
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
    # tailscale

    # GUI apps via brew-nix
    aerospace
    audacity
    brewCasks.bitwarden
    brewCasks.gimp
    brewCasks.helium-browser
    inkscape
    localsend
    mpv-unwrapped
    brewCasks.obs
    steam-unwrapped
    # brewCasks.tailscale-app

    brewCasks.zen
    zoom-us
    zotero
  ];

  programs = {
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      shellAliases = {
        k = "kubectl";
        kg = "kubectl get";
        kcf = "kubectl create -f";
        kdf = "kubectl delete -f";
        kaf = "kubectl apply -f";
        l = "eza -1al --icons=always --group-directories-first --total-size";

        wget = "wget --hsts-file=$XDG_DATA_HOME/wget-hsts";
      };
    };
  };

  home.sessionVariables = {
    # Existing XDG redirects
    PARALLEL_HOME = "${config.xdg.configHome}/parallel";
    CARGO_HOME = "${config.xdg.dataHome}/cargo";
    RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
    SQLITE_HISTORY = "${config.xdg.cacheHome}/sqlite_history";

    # Tool data/config/cache
    WGET_HSTS_FILE = "${config.xdg.dataHome}/wget/wget-hsts";
    NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
    NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
    MATPLOTLIBRC = "${config.xdg.configHome}/matplotlib/matplotlibrc";
    JUPYTER_DATA_DIR = "${config.xdg.dataHome}/jupyter";
    ANSIBLE_CONFIG = "${config.xdg.configHome}/ansible/ansible.cfg";
  };

  # home.packages = with pkgs; [
  #   xdg-utils
  #   xdg-user-dirs
  # ];

  imports = [
    # ./programs/alacritty
    ./programs/direnv
    ./programs/ghostty
    ./programs/gnupg
    ./programs/k9s
    ./programs/neovim
    ./programs/pi
    # ./programs/nix-search
    # ./programs/pass
    ./programs/starship
    ./programs/taskwarrior
    ./programs/tmux
  ];
}
