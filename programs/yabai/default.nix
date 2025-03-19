{ pkgs, ... }: {
  services.yabai = {
    enable = true;
    package = pkgs.yabai;
    config = {
      external_bar = "all:34:0";
      layout = "bsp";

      window_placement = "second_child";
      menubar_opacity = "0.0";

      mouse_modifier = "alt";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "swap";

      top_padding = 10;
      bottom_padding = 10;
      left_padding = 10;
      right_padding = 10;
      window_gap = 10;
    };
  };
}
