{pkgs, ...}: {
  home = {
    username = "napatsc";
    homeDirectory = "/Users/napatsc";
    stateVersion = "25.05";
  };

  xdg.enable = true;

  programs = {
    home-manager.enable = true;
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
      initContent = ''
        eval "$(direnv hook zsh)"
      '';
    };
  };

  imports = [
    ./programs/alacritty
    ./programs/direnv
    ./programs/k9s
    ./programs/neovim
    ./programs/starship
    ./programs/taskwarrior
    ./programs/tmux
  ];
}
