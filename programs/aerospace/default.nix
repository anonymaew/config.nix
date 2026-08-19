# Aerospace — tiling window manager (config + launchd)
{ ... }: {
  flake.homeModules.aerospace = { pkgs, ... }: {
    programs.aerospace = {
      enable = true;
      package = pkgs.aerospace;
    };

    xdg.configFile."aerospace/aerospace.toml".source = ./aerospace.toml;
  };
}
