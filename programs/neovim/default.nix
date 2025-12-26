{ pkgs, neovim-nightly, ... }:
{
  programs.neovim = {
    enable = true;
    package = neovim-nightly.packages.${pkgs.system}.neovim-nightly;
    extraPackages = with pkgs; [
      # programming language platform
      cargo
      nodejs_24

      # lsp
      alejandra
      nil
      svelte-language-server
      typescript-language-server
      vscode-langservers-extracted

      # optional deps
      ripgrep
    ];
  };
  xdg.configFile."nvim/init.lua".source = ./init.lua;
}
