# ghostty — GPU-accelerated terminal emulator
{ ... }: {
  flake.homeModules.ghostty = { pkgs, ... }: {
    programs.ghostty = {
      enable = true;
      package = pkgs.brewCasks.ghostty;
      enableZshIntegration = true;
    };

    # Config lives in config.ghostty ($XDG_CONFIG_HOME/ghostty/config.ghostty)
    xdg.configFile."ghostty/config.ghostty".source = ./config.ghostty;
  };
}
