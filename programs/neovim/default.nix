# neovim — text editor
{ ... }: {
  flake.homeModules.neovim = { pkgs, ... }:
    let
      sharedInit = ./init.lua;
    in
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;

        extraPackages = with pkgs; [
          cargo
          nodejs_24
          alejandra
          ltex-ls
          lua-language-server
          nil
          oxlint
          ruff
          rust-analyzer
          svelte-language-server
          tinymist
          typescript-language-server
          typos-lsp
          vscode-langservers-extracted
          ripgrep
        ];

        plugins = with pkgs.vimPlugins; [
          nvim-lspconfig
          vscode-nvim
          nvim-web-devicons
          lualine-nvim
          indent-blankline-nvim
          oil-nvim
          nvim-origami
        ];
      };

      xdg.configFile."nvim/init.lua".text = ''
        vim.g.nix_mode = true
        dofile(vim.fn.stdpath("config") .. "/nvim.lua")
      '';
      xdg.configFile."nvim/nvim.lua".source = sharedInit;
    };
}
