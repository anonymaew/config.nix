{ pkgs, ... }: {
  home = {
    username = "napatsc";
    homeDirectory = "/Users/napatsc";
    stateVersion = "24.05";
  };

  xdg.enable = true;

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      dotDir = ".config/zsh";
      history.path = "$ZDOTDIR/.zsh_history";
      shellAliases = {
        k = "kubectl";
        kg = "kubectl get";
        kcf = "kubectl create -f";
        kdf = "kubectl delete -f";
        kaf = "kubectl apply -f";
        l = "eza -1al --icons=always --group-directories-first --total-size";
      };
      initExtra = ''
        eval "$(direnv hook zsh)"
      '';
      sessionVariables = {
        PYTHON_HISTORY = "$XDG_STATE_HOME/python_history";
      };
    };
  };

  imports = [
    ./programs/alacritty
    ./programs/k9s
    ./programs/neovim
    ./programs/starship
    ./programs/taskwarrior
    ./programs/tmux
  ];
}
