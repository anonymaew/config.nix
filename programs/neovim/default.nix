{ pkgs, neovim-nightly, ... }:
{
  programs.neovim = {
    enable = true;
    package = neovim-nightly.packages.${pkgs.system}.neovim-nightly;
    extraPackages = with pkgs; [
      cargo
      nodejs_24

      alejandra
      nil
    ];
  };
  xdg.configFile."nvim/init.lua".source = ./init.lua;
}
