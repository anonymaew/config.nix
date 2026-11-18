# neovim — text editor
{ ... }: {
  flake.homeModules.neovim =
    { pkgs, ... }:
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
          harper
          lua-language-server
          nil
          # oxlint
          ruff
          rust-analyzer
          svelte-language-server
          tinymist
          ty
          typescript-language-server
          typos-lsp
          vscode-langservers-extracted
          ripgrep
        ];

        plugins = with pkgs.vimPlugins; [
          # Treesitter grammars. Neovim 0.12 only bundles c, lua, markdown,
          # markdown_inline, query, vim and vimdoc; init.lua calls
          # vim.treesitter.start() on every FileType, so anything else warns
          # "parser not available" (and foldexpr = treesitter is a no-op).
          # nvim-treesitter ships the queries (highlights/folds/indents); the
          # parsers come in as plugin dependencies of withPlugins.
          (nvim-treesitter.withPlugins (p: with p; [
            bash
            css
            diff
            html
            javascript
            json
            lua
            markdown
            markdown_inline
            nix
            python
            rust
            svelte
            toml
            tsx
            typescript
            typst
            yaml
          ]))
          nvim-lspconfig
          vscode-nvim
          nvim-web-devicons
          lualine-nvim
          indent-blankline-nvim
          oil-nvim
          nvim-origami
          # Session manager for the herdr editor restore: one session per
          # working directory, loaded when nvim starts with no file argument.
          # See herdr-sessions.lua for the label the shell hook reads.
          resession-nvim
        ];
      };

      xdg.configFile."nvim/init.lua".text = ''
        vim.g.nix_mode = true
        dofile(vim.fn.stdpath("config") .. "/nvim.lua")
      '';
      xdg.configFile."nvim/nvim.lua".source = sharedInit;
      # Autoloaded from nvim/plugin/, so init.lua stays untouched.
      xdg.configFile."nvim/plugin/herdr-sessions.lua".source = ./herdr-sessions.lua;
    };
}
