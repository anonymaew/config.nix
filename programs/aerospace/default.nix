# Aerospace — tiling window manager (config + launchd)
{ ... }: {
  flake.homeModules.aerospace = { pkgs, ... }: {
    programs.aerospace = {
      enable = true;
      package = pkgs.aerospace;
      launchd.enable = true;
      settings = {
        on-first-launch-no-window = "layout tiling";
      };
    };

    xdg.configFile."aerospace/aerospace.toml".source = ./aerospace.toml;
  };
}
