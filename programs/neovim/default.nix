{...}: {
  programs.nixvim = {
    enable = true;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    colorschemes.vscode = {
      enable = true;
      settings.transparent = true;
    };

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      number = true;
      shiftwidth = 2;
      undofile = true;
      swapfile = false;
      clipboard = "unnamedplus";
      # no weird sign shifting
      signcolumn = "yes";
    };
    # keep the sign on when typing
    diagnostic.settings.update_in_insert = true;

    keymaps = [
      {
        mode = "n";
        key = "[d";
        action = "vim.diagnostic.goto_prev";
      }
      {
        mode = "n";
        key = "]d";
        action = "vim.diagnostic.goto_next";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "vim.diagnostic.open_float";
      }
    ];

    plugins = {
      # tab space by line guidance
      indent-blankline.enable = true;
      # customize the line below
      lualine.enable = true;

      # navigate between vim/tmux
      tmux-navigator.enable = true;

      # let us commenting by gc
      comment.enable = true;

      # tpope plugins
      sleuth.enable = true;
      fugitive.enable = true;
      vim-surround.enable = true;

      # oil
      oil.enable = true;

      # better syntax highlighter
      treesitter = {
        enable = true;
        settings = {
          highlight = {
            enable = true;
            disable = ["latex"];
          };
          indent.enable = true;
        };
      };
      # highlighter inside codeblock
      otter.enable = true;

      # formatter
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            cpp = ["clang_format"];
            python = ["ruff_organize_imports" "ruff_format"];
            javascript = ["prettierd"];
            javascriptreact = ["prettierd"];
            typescript = ["prettierd"];
            typescriptreact = ["prettierd"];
            html = ["prettierd"];
            htmlhugo = ["prettierd"];
            astro = ["prettierd"];
            nix = ["alejandra"];
          };
          # allows formatting on save
          format_on_save = {
            lsp_fallback = true;
            async = false;
            timeout_ms = 500;
          };
        };
      };

      # lsp servers
      lsp = {
        enable = true;
        servers = {
          astro.enable = true;
          clangd.enable = true;
          # ts_ls.enable = true;
          nil_ls.enable = true;
          tinymist = {
            enable = true;
            settings = {
              formatterMode = "typstyle";
              exportPdf = "onType";
              #   semanticTokens = "disable";
            };
          };
          pylsp.enable = true;
          ruff.enable = true;
        };
        # shortcut keys related to LSP
        keymaps.lspBuf = {
          "gd" = "definition";
          "gD" = "references";
          "gt" = "type_definition";
          "gi" = "implementation";
          "<leader>ca" = "code_action";
          "<leader>rn" = "rename";
          "K" = "hover";
        };
      };

      # autocompletion
      blink-cmp = {
        enable = true;
        settings = {
          appearance = {
            nerd_font_variant = "normal";
            use_nvim_cmp_as_default = true;
          };
          completion.menu = {
            border = "rounded";
          };
        };
      };

      # hinting better moves
      hardtime = {
        enable = true;
        settings.restriction_mode = "hint";
      };

      # notification box
      notify = {
        enable = true;
        settings = {
          background_colour = "#000000";
          render = "wrapped-compact";
          stages = "static";
        };
      };

      web-devicons.enable = true;
    };
  };
  # xdg.configFile."nvim/init.lua".source = ./init.lua;
}
