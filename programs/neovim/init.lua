--------------------
-- Common options --
--------------------
vim.opt.number = true             -- enable line number
vim.opt.tabstop = 2               -- tab has a length of 2 space
vim.opt.shiftwidth = 2            -- inserting tab has a length of 2 space
vim.opt.winborder = 'rounded'     -- rounded window box border
vim.opt.undofile = true           -- allow undo after reopening
vim.opt.swapfile = false          -- disable hidden swapfiles for buffer
vim.opt.clipboard = 'unnamedplus' -- allow sharing with system clipboard
vim.opt.signcolumn = 'yes'        -- show warning on number col
vim.opt.textwidth = 80
vim.diagnostic.config({
	update_in_insert = true, -- keep showing warning while typing
	virtual_text = true,    -- warning text inline
})

-----------------
-- LSP related --
-----------------
vim.pack.add({
	-- lsp registries
	{ src = 'https://github.com/mason-org/mason.nvim' },
	-- lsp config registries
	{ src = 'https://github.com/neovim/nvim-lspconfig' },
	-- declaratively install lsp servers
	{ src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
})
require('mason').setup()
require('mason-lspconfig').setup({
	-- define lsp servers here
	ensure_installed = {
		'ltex_plus', 'lua_ls', 'ruff', 'rust_analyzer', 'svelte', 'tinymist', 'ty'
	}
})
vim.lsp.config('tinymist', { -- typst: compile PDF on save (titled doc)
	settings = { exportPdf = 'onDocumentHasTitle' },
})
vim.lsp.config('lua_ls', { -- lua: making awareness of vim api
	settings = {
		Lua = {
			diagnostic = { globals = { 'vim' } },
			workspace = { library = vim.api.nvim_get_runtime_file("", true) }
		}
	}
})
vim.lsp.enable('nil_ls')

-- show autocompletion window on type and do linting on save
-- source: https://neovim.io/doc/user/lsp.html#lsp-attach
vim.api.nvim_create_autocmd('LspAttach', {
	group = vim.api.nvim_create_augroup('my.lsp', {}),
	callback = function(args)
		local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
		if client:supports_method('textDocument/implementation') then
			-- Create a keymap for vim.lsp.buf.implementation ...
		end
		-- Enable auto-completion. Note: Use CTRL-Y to select an item. |complete_CTRL-Y|
		if client:supports_method('textDocument/completion') then
			-- Optional: trigger autocompletion on EVERY keypress. May be slow!
			-- local chars = {}; for i = 32, 126 do table.insert(chars, string.char(i)) end
			-- client.server_capabilities.completionProvider.triggerCharacters = chars
			vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
		end
		-- Auto-format ("lint") on save.
		-- Usually not needed if server supports "textDocument/willSaveWaitUntil".
		if not client:supports_method('textDocument/willSaveWaitUntil')
				and client:supports_method('textDocument/formatting') then
			vim.api.nvim_create_autocmd('BufWritePre', {
				group = vim.api.nvim_create_augroup('my.lsp', { clear = false }),
				buffer = args.buf,
				callback = function()
					vim.lsp.buf.format({ bufnr = args.buf, id = client.id, timeout_ms = 1000 })
				end,
			})
		end
	end,
})
-- not select the first result on popup yet
vim.opt.completeopt = "menuone,noinsert,popup"

----------------------------------
-- Decorations/QoL improvements --
----------------------------------
vim.pack.add({
	-- vscode theme
	{ src = 'https://github.com/Mofiqul/vscode.nvim' },
	--
	{ src = 'https://github.com/christoomey/vim-tmux-navigator' },
	-- icons; allow plugins to use nerdfont icons
	{ src = 'https://github.com/nvim-tree/nvim-web-devicons' },
	-- lualine; beautify bottom status bar
	{ src = 'https://github.com/nvim-lualine/lualine.nvim' },
	-- tab space by line guidance
	{ src = 'https://github.com/lukas-reineke/indent-blankline.nvim' },
	-- oil; enable files editing like vim
	{ src = 'https://github.com/stevearc/oil.nvim' },
})

require('vscode').setup({
	transparent = true,
	italic_comments = true,
})
vim.cmd.colorscheme('vscode')
-- require('tmux-navigator').setup()
require('lualine').setup({
	options = {
		section_separators = '', component_separators = '|'
	}
})
require('ibl').setup()
require('oil').setup()
