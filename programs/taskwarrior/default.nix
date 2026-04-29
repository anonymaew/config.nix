{pkgs, ...}: {
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-16";
  };
}
