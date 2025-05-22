{
  pkgs,
  vars,
  ...
}: {
  services.sketchybar = {
    enable = true;
    package = pkgs.sketchybar;
    extraPackages = with pkgs; [
      ifstat-legacy
    ];
  };
  home-manager.users.${vars.name}.xdg.configFile."sketchybar" = {
    source = ./config;
    recursive = true;
    onChange = "sketchybar --reload";
  };
}
