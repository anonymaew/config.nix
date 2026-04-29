{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
		defaultEditor = true;
    extraPackages = with pkgs; [
      # programming language platform
      cargo
      nodejs_24

      # lsp
      alejandra
      nil
			oxlint
      svelte-language-server
      typescript-language-server
      vscode-langservers-extracted

      # optional deps
      ripgrep
    ];
  };
  xdg.configFile."nvim/init.lua".source = ./init.lua;
}
