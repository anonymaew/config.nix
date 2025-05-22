{
  pkgs,
  vars,
  ...
}: {
  programs.alacritty = {
    enable = true;
    settings = {
      general.import = ["~/.config/alacritty/colors.toml"];
      env.TERM = "xterm-256color";
      window = {
        padding = {
          x = 6;
          y = 10;
        };
        opacity = 0.8;
        blur = true;
      };
      font = {
        size = 13;
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Medium";
        };
        offset.x = 1;
      };
      bell = {
        command = {
          program = "osascript";
          args = ["-e" "beep"];
        };
      };
    };
  };
  xdg.configFile."alacritty/colors.toml".source = ./colors.toml;
}
