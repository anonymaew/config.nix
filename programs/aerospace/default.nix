{ pkgs, vars, ... }: {
  home-manager.users.${vars.name}.xdg.configFile."aerospace" = {
    source = ./aerospace.toml;
    target = "./aerospace/aerospace.toml";
  };
}
