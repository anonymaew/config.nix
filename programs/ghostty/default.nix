{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.brewCasks.ghostty;
    enableZshIntegration = true;
    settings = {
      theme = "dark:Catppuccin Mocha,light:Catppuccin Latte";
      # font-family = ["JetBrainsMonoNL Nerd Font Mono"];
      font-feature = ["-calt" "-liga" "-dlig"];
      # macos-titlebar-proxy-icon = "hidden";
      macos-titlebar-style = "hidden";
      window-padding-x = 6;
      window-padding-y = 6;
      background-blur = true;
      background-opacity = 0.8;
    };
  };
}
