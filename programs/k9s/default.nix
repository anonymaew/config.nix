# k9s — Kubernetes CLI dashboard
{ ... }: {
  flake.homeModules.k9s = { ... }: {
    programs.k9s = {
      enable = true;
    };

    # Config lives in config.yaml + skins/ ($XDG_CONFIG_HOME/k9s/)
    xdg.configFile."k9s/config.yaml".source = ./config.yaml;
    xdg.configFile."k9s/skins/catppuccin.yaml".source = ./skins/catppuccin.yaml;
  };
}
