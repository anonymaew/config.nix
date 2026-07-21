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
    # tailscale

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
    mpv-unwrapped
    brewCasks.obs
    steam-unwrapped
    # brewCasks.tailscale-app

    brewCasks.slack
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
