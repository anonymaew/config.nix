{config, ...}: {
  home = {
    username = "napatsc";
    homeDirectory = "/Users/napatsc";
    stateVersion = "26.05";
  };

  xdg.enable = true;

  programs = {
    home-manager.enable = true;
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      history.path = "${config.xdg.configHome}/zsh/.zsh_history";
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
    PARALLEL_HOME = "${config.xdg.configHome}/parallel";
    CARGO_HOME = "${config.xdg.dataHome}/cargo";
    RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
    SQLITE_HISTORY = "${config.xdg.cacheHome}/sqlite_history";
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
    # ./programs/nix-search
    # ./programs/pass
    ./programs/starship
    ./programs/taskwarrior
    ./programs/tmux
  ];
}
