# starship — shell prompt
{ ... }: {
  flake.homeModules.starship = { ... }: {
    programs.starship = {
      enable = true;
      # All settings live in starship.toml (see xdg.configFile below)
    };
    xdg.configFile."starship.toml".source = ./starship.toml;
  };
}
