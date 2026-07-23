# direnv — environment directory switcher
{ ... }: {
  flake.homeModules.direnv = { ... }: {
    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
    xdg.configFile."direnv/direnvrc".source = ./direnvrc;
  };
}
