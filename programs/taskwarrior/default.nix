{ pkgs, lib, ... }: {
  programs.taskwarrior = {
    enable = true;
    colorTheme = "dark-16";
  };
}
