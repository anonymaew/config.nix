# neovim — text editor
{ ... }: {
  flake.homeModules.neovim =
    { pkgs, ... }:
    let
      sharedInit = ./init.lua;
      # Notebook (molten + image.nvim) python env, used three ways:
      #  * `extraPython3Packages` keeps home-manager's own python3 host env
      #    identical (same package list => same store path);
      #  * `xdg.configFile."nvim/init.lua"` points g:python3_host_prog at it,
      #    because molten is a python remote plugin (needs pynvim, jupyter_client);
      #  * it goes on PATH because the python3 kernel spec that ipykernel installs
      #    launches `python -m ipykernel_launcher`, and nothing else in PATH
      #    provides a `python` binary.
      notebookPython = ps: with ps; [
        pynvim
        jupyter-client
        ipykernel # kernelspec python3 + kernel runtime; needs `python` on PATH
        nbformat # :MoltenImportOutput / :MoltenExportOutput (.ipynb)
        jupytext # the `jupytext` CLI jupytext-nvim shells out to (opens .ipynb as .py)
        pillow # :MoltenImagePopup
        pyperclip # :MoltenCopyOutput
      ];
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
          imagemagick # image.nvim `magick_cli` processor (plots from molten)
          lua-language-server
          nil
          # oxlint
          (python3.withPackages notebookPython) # `python` for the jupyter kernel
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

        extraPython3Packages = notebookPython;

        plugins = with pkgs.vimPlugins; [
          # Notebook workflow: molten runs code in a jupyter kernel and renders
          # output under the cell; image.nvim renders plots inline.
          # NOTE: molten is a *remote* plugin, so run `:UpdateRemotePlugins`
          # once after the first switch (writes stdpath('data')/rplugin.vim).
          molten-nvim
          image-nvim
          # .ipynb is JSON; this re-reads it through the `jupytext` CLI as the
          # matching plain-text form and writes the notebook back on :w. Python
          # notebooks use the `markdown` style (prose stays markdown, code goes
          # into ```python fences), see init.lua.
          jupytext-nvim
          # Gives those fenced code blocks a real LSP (ruff/ty) and completion:
          # otter keeps hidden python buffers in sync with the markdown buffer
          # and forwards LSP requests to them.
          otter-nvim
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
        -- home-manager prepends `vim.g.loaded_..._provider=0` for every provider
        -- (it expects the nixpkgs wrapper to re-enable them; this module writes
        -- the paths itself instead). For python3 that flag is fatal: nvim's
        -- autoload/provider/python3.vim starts with
        -- `if exists('g:loaded_python3_provider') | finish`, so it never defines
        -- provider#python3#Require and `:UpdateRemotePlugins` dies with
        -- E117: Unknown function: provider#python3#Require (molten never registers).
        vim.g.loaded_python3_provider = nil
        -- molten is a python remote plugin, so nvim needs a python3 host that can
        -- import pynvim + jupyter_client. Set explicitly: provider discovery
        -- would otherwise find /usr/bin/python3 first.
        vim.g.python3_host_prog = "${pkgs.python3.withPackages notebookPython}/bin/python3";
        dofile(vim.fn.stdpath("config") .. "/nvim.lua")
      '';
      xdg.configFile."nvim/nvim.lua".source = sharedInit;
      # Autoloaded from nvim/plugin/, so init.lua stays untouched.
      xdg.configFile."nvim/plugin/herdr-sessions.lua".source = ./herdr-sessions.lua;
    };
}
