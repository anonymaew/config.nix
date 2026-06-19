{ pkgs, ... }:
let
  # Same init.lua used on both Nix and non-Nix:
  # - On Nix: loaded via wrapper (sets sentinel, then dofile)
  # - On non-Nix: copy directly to ~/.config/nvim/init.lua
  sharedInit = ./init.lua;
in {
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    extraPackages = with pkgs; [
      # programming language platform
      cargo
      nodejs_24

      # lsp servers (must match lsp_servers in init.lua)
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

      # optional deps
      ripgrep
    ];

    plugins = with pkgs.vimPlugins; [
      # lsp config (servers come from extraPackages)
      nvim-lspconfig

      # decorations / qol
      vscode-nvim
      nvim-web-devicons
      lualine-nvim
      indent-blankline-nvim
      oil-nvim
      nvim-origami
    ];
  };

  # Nix wrapper: set sentinel, then load shared Lua config.
  # On non-Nix machines users copy init.lua directly (no sentinel → vim.pack.add runs).
  xdg.configFile."nvim/init.lua".text = ''
    vim.g.nix_mode = true
    dofile(vim.fn.stdpath("config") .. "/nvim.lua")
  '';
  xdg.configFile."nvim/nvim.lua".source = sharedInit;
}
