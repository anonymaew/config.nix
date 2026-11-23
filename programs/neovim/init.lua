-- Non-Nix machines: needs npm, cargo, python3 for LSP server installation.
-- Install deps first, or set vim.g.nix_mode=true to skip Mason entirely.

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
vim.opt.signcolumn = 'number'     -- show warning on number col
vim.opt.textwidth = 80            -- window size: 80 chars
-- folding related
vim.opt.foldenable = false        -- dont fold all code when open
vim.opt.foldtext = ''             -- folded text: highlight, no stats
-- use treesitter syntax as folding method (optimal)
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldmethod = 'expr'
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

vim.diagnostic.config({
	update_in_insert = true, -- keep showing warning while typing
	virtual_text = true,    -- warning text inline
})

-----------------------
-- Plugin management --
-----------------------
-- On Nix: plugins come from programs.neovim.plugins (default.nix)
-- On non-Nix: install via vim.pack.add()
if not vim.g.nix_mode then
	-- LSP / tool plugins
	vim.pack.add({
		{ src = 'https://github.com/mason-org/mason.nvim' },
		{ src = 'https://github.com/neovim/nvim-lspconfig' },
		{ src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
	})
	-- Decorations / QoL plugins
	vim.pack.add({
		-- vscode theme
		{ src = 'https://github.com/Mofiqul/vscode.nvim' },
		-- icons; allow plugins to use nerdfont icons
		{ src = 'https://github.com/nvim-tree/nvim-web-devicons' },
		-- lualine; beautify bottom status bar
		{ src = 'https://github.com/nvim-lualine/lualine.nvim' },
		-- tab space by line guidance
		{ src = 'https://github.com/lukas-reineke/indent-blankline.nvim' },
		-- oil; enable files editing like vim
		{ src = 'https://github.com/stevearc/oil.nvim' },
		-- Agentic AI coding
		-- { src = 'https://www.github.com/nvim-lua/plenary.nvim' },
		-- { src = 'https://www.github.com/olimorris/codecompanion.nvim' },
		-- better code folding
		{ src = 'https://github.com/chrisgrieser/nvim-origami' },
	})
end

-----------------
-- LSP related --
-----------------
-- Servers to enable.
-- NOTE: "ty" (astral's python type checker + language server) is not in the Mason
--       registry, and mason-lspconfig rejects unknown `ensure_installed` entries.
--       So it is added only on Nix, where servers come from extraPackages.
--       Elsewhere: `uv tool install ty`.
--       Not to be confused with "typos_lsp", the spell checker.
local lsp_servers = {
	'eslint', 'harper_ls', 'html', 'lua_ls', 'nil_ls', 'ruff', 'rust_analyzer',
	'svelte', 'tinymist', 'ts_ls'
};
if vim.g.nix_mode then -- nvim-lspconfig ships lsp/ty.lua: { cmd = { 'ty', 'server' } }
	table.insert(lsp_servers, 'ty')
end

-- Custom LSP configs (must be set BEFORE enabling servers, so overrides take effect)
vim.lsp.config('tinymist', { -- typst: compile PDF on save (titled doc)
	settings = { exportPdf = 'onDocumentHasTitle' },
})
vim.lsp.config('harper_ls', { -- english: settings must be an object under a "harper-ls" key
	-- Required on v2 *and* v3: `Config::from_lsp_config` bails with "Settings must
	-- be an object." when the client pushes `settings = null` (nvim does that when
	-- no settings are configured) and also unless the object has a "harper-ls"
	-- key. Verified in the v3.0.0 source; upstream issue #3151 is still open.
	-- Skipping this writes the ERROR to ~/.local/state/nvim/lsp.log on every
	-- config pull / buffer attach (50MB in one month). All 15 config keys and the
	-- linter names below are unchanged between 2.13.0 and 3.0.0.
	settings = {
		['harper-ls'] = {
			dialect = 'American',        -- American|British|Australian|Canadian|Indian
			diagnosticSeverity = 'hint', -- error|warning|information|hint; v3 default is hint
			-- NOTE: the nvim config dir is nix-managed (read-only symlinks), so keep
			-- the dictionary in the data dir instead of ~/.config/nvim.
			userDictPath = vim.fn.stdpath('data') .. '/harper-dict.txt',
			maxFileLength = 120000, -- v3 default; skip linting huge scratch files
			linters = {
				SpellCheck = true,
				RepeatedWords = true,
				LongSentences = true,
				Spaces = true,
			},
		},
	},
})
vim.lsp.config('lua_ls', { -- lua: making awareness of vim api
	settings = {
		Lua = {
			diagnostic = { globals = { 'vim' } },
			workspace = { library = vim.api.nvim_get_runtime_file("", true) }
		}
	}
})
vim.lsp.config('oxfmt', {})

if vim.g.nix_mode then
	-- Nix: LSP servers from extraPackages (in PATH).
	-- Use built-in vim.lsp.enable (the new nvim-lspconfig 2.x API) instead of
	-- the deprecated require('lspconfig').<server>.setup({}).
	for _, server in ipairs(lsp_servers) do
		pcall(vim.lsp.enable, server)
	end
else
	-- Non-Nix: use Mason to install and configure LSP servers
	require('mason').setup()
	require('mason-lspconfig').setup({
		-- define lsp servers here
		ensure_installed = lsp_servers
	})
end

-- start treesitter automatically
-- The autocmd fires for EVERY filetype, including ones that have no grammar at
-- all (oil/oil_preview buffers, pickers, quickfix, `text`, ...). vim.treesitter
-- .start() raises "Parser could not be created for buffer N and language X" for
-- those, so check the parser first and skip silently instead of notifying.
-- language.add() returns nil (no error) when no parser is installed.
vim.api.nvim_create_autocmd('FileType', {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		local lang = vim.treesitter.language.get_lang(ft) or ft
		if not vim.treesitter.language.add(lang) then
			return -- no grammar for this filetype (oil, text, ...): nothing to do
		end
		vim.treesitter.start(args.buf, lang)
	end,
})

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
require('vscode').setup({
	transparent = true,
})
vim.cmd.colorscheme('vscode')
require('lualine').setup({
	options = {
		section_separators = '', component_separators = '|'
	}
})
require('ibl').setup()
require('oil').setup()
require('origami').setup()

------------------------------
-- Notebooks (image+molten) --
------------------------------
-- image.nvim renders the plots/figures molten gets from the kernel.
-- `magick_cli` shells out to `magick` (imagemagick is in extraPackages); the
-- default `magick_rock` would need the lua rock in extraLuaPackages.
-- The kitty backend works in ghostty, and inside tmux because tmux.conf sets
-- `allow-passthrough on`. Other terminals just don't show the images.
require('image').setup({
	backend = 'kitty',
	processor = 'magick_cli',
	max_width = 60,
	max_height = 20,
})

-- molten is a python remote plugin: run ":UpdateRemotePlugins" once after the
-- first switch (it writes stdpath('data')/rplugin.vim), then ":checkhealth molten".
-- Options are read from vim.g at run time, so there is no setup() call; only the
-- ones that differ from molten's defaults are set here.
vim.g.molten_image_provider = 'image.nvim' -- inline plots, needs image.nvim above
vim.g.molten_output_win_max_height = 20    -- default 999999: a full-screen float

-- maplocalleader was unset (Vim's default is `\`, awkward on a laptop keyboard).
vim.g.maplocalleader = ','
vim.keymap.set('n', '<localleader>mi', ':MoltenInit<CR>', { desc = 'molten: pick kernel' })
vim.keymap.set('n', '<localleader>ml', ':MoltenEvaluateLine<CR>', { desc = 'molten: run line' })
vim.keymap.set('n', '<localleader>mr', ':MoltenReevaluateCell<CR>', { desc = 'molten: re-run cell' })
-- `<localleader>mb` (run a whole ```block) is notebook-only, see the FileType
-- autocmd below.
vim.keymap.set('v', '<localleader>mr', ':<C-u>MoltenEvaluateVisual<CR>gv', {
	desc = 'molten: run selection',
})

-- `:MoltenInit` only knows jupyter kernelspecs, so a project venv is invisible
-- until one exists for it. The venv of the buffer's project ($VIRTUAL_ENV, else
-- the nearest `.venv` up the tree) gets its kernelspec written where
-- `ipykernel install --user` puts it, and a kernel is started from it: opening a
-- notebook does that automatically, `<localleader>mv` redoes it on demand.
local function project_venv(buf)
	local venv = vim.env.VIRTUAL_ENV
	if venv ~= nil and venv ~= '' then
		return venv
	end
	local from = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p:h')
	from = vim.fn.isdirectory(from) == 1 and from or vim.fn.getcwd()
	return vim.fs.find('.venv', { path = from, upward = true, type = 'directory' })[1]
end

local function venv_kernel_name(venv)
	local base = vim.fn.fnamemodify(venv, ':t')
	if base == '.venv' or base == 'venv' then
		base = vim.fn.fnamemodify(vim.fn.fnamemodify(venv, ':h'), ':t')
	end
	return (base:gsub('[^%w%-_.]', '-'))
end

---Write (or refresh) the kernelspec for `venv`. Returns the kernel name, or nil
---when the venv cannot run a kernel (`quiet` = only worth an INFO message).
local function venv_kernel_spec(venv, quiet)
	local python = venv .. '/bin/python'
	if vim.fn.executable(python) ~= 1 then
		vim.notify('molten: ' .. python .. ' is not executable', quiet and vim.log.levels.INFO or vim.log.levels.ERROR)
		return nil
	end
	if vim.fn.system({ python, '-c', 'import ipykernel' }) ~= '' or vim.v.shell_error ~= 0 then
		vim.notify(
			'molten: ipykernel is not installed in ' .. venv .. '\n  uv add --dev ipykernel',
			quiet and vim.log.levels.INFO or vim.log.levels.ERROR
		)
		return nil
	end

	-- same lookup order as jupyter_core
	local data_dir = vim.env.JUPYTER_DATA_DIR
	if data_dir == nil or data_dir == '' then
		data_dir = vim.env.XDG_DATA_HOME ~= nil and (vim.env.XDG_DATA_HOME .. '/jupyter')
			or (vim.env.HOME .. '/.local/share/jupyter')
	end
	local name = venv_kernel_name(venv)
	local spec_dir = ('%s/kernels/%s'):format(data_dir, name)
	local spec_file = spec_dir .. '/kernel.json'
	-- same basename, different venv (two `homework-5` dirs, ...): keep both
	local ok, existing = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(spec_file), '\n'))
	end)
	if ok and existing and existing.argv and existing.argv[1] and existing.argv[1] ~= python then
		name = ('%s-%s'):format(name, vim.fn.sha256(venv):sub(1, 4))
		spec_dir = ('%s/kernels/%s'):format(data_dir, name)
		spec_file = spec_dir .. '/kernel.json'
	end
	vim.fn.mkdir(spec_dir, 'p')
	-- jupyter_client drops the connection file in <data_dir>/runtime and only
	-- creates the directory itself when it already used it once.
	vim.fn.mkdir(data_dir .. '/runtime', 'p')
	vim.fn.writefile({
		vim.json.encode({
			argv = { python, '-m', 'ipykernel_launcher', '-f', '{connection_file}' },
			display_name = ('Python 3 (%s)'):format(name),
			language = 'python',
		}),
	}, spec_file)
	return name
end

local function molten_init_venv()
	local venv = project_venv(0)
	if not venv then
		vim.notify('molten: no venv found (no $VIRTUAL_ENV, no .venv above this file)', vim.log.levels.WARN)
		return
	end
	local name = venv_kernel_spec(venv, false)
	if name then
		vim.cmd('MoltenInit ' .. name)
	end
end
vim.keymap.set('n', '<localleader>mv', molten_init_venv, {
	desc = 'molten: start kernel from the project venv',
})

-- .ipynb is raw JSON on disk. jupytext-nvim installs a BufReadCmd for *.ipynb
-- that shells out to the `jupytext` CLI (in notebookPython) and puts the
-- plain-text form in the buffer; :w converts back to JSON. No lazy-loading:
-- the autocmd is created in setup().
-- The `markdown` style keeps prose as real markdown and turns code cells into
-- ```python fences (the `hydrogen` style instead comments prose out and uses
-- `# %%` markers in a .py buffer). Markdown cells keep their metadata in HTML
-- comments like `<!-- #region id="..." -->`, which are invisible when rendered.
require('jupytext').setup({
	style = 'markdown',
	custom_language_formatting = {
		python = { extension = 'md', style = 'markdown', force_ft = 'markdown' },
	},
})

-- otter: fenced code blocks only get syntax colouring from treesitter's markdown
-- injection queries -- no ruff/ty, no completion. otter runs a hidden python
-- buffer per notebook, keeps it in sync, and routes LSP requests (hover,
-- definition, completion, diagnostics) to it. Its own `otter-ls` is what the md
-- buffer talks to; ruff/ty attach to the hidden buffers via their normal
-- filetype activation (vim.lsp.enable above), so no otter-ls setup is needed.
-- `handle_leading_whitespace = false` keeps the hidden buffer's column numbers
-- identical to the fence, so diagnostics can be copied over verbatim below.
require('otter').setup({ handle_leading_whitespace = false })

-- ruff/ty do publish for the hidden buffer (see
-- `:lua vim.diagnostic.get(<otter bufnr>)`), but otter's own mirroring hook only
-- starts listening *after* the first results for a notebook have arrived, so the
-- markdown buffer stayed free of code diagnostics. Mirror them ourselves, under
-- our own namespace, for every diagnosis that lands on a raft buffer.
local notebook_diag_ns = vim.api.nvim_create_namespace('notebook-code-diagnostics')

local function mirror_code_diagnostics(main)
	local raft = require('otter.keeper').rafts[main]
	if not raft then
		return
	end
	vim.diagnostic.reset(notebook_diag_ns, main)
	for _, otter_buf in pairs(raft.buffers) do
		local diagnostics = vim.diagnostic.get(otter_buf)
		if #diagnostics > 0 then
			vim.diagnostic.set(notebook_diag_ns, main, diagnostics, {})
		end
	end
end

vim.api.nvim_create_autocmd('DiagnosticChanged', {
	callback = function(args)
		for main, raft in pairs(require('otter.keeper').rafts) do
			if vim.tbl_contains(vim.tbl_values(raft.buffers), args.buf) then
				mirror_code_diagnostics(main)
			end
		end
	end,
})

-- Notebook folding, both cell kinds:
--  * code cells are ```fences -> taken from the treesitter `fenced_code_block`
--    nodes (nvim-treesitter's markdown fold query is not used: it also folds
--    `section`, i.e. from one heading to the next = the whole document);
--  * markdown cells are wrapped by jupytext in `<!-- #region ... -->` /
--    `<!-- #endregion -->` comments -> folded by scanning for those markers.
-- A fence inside a markdown cell nests one level deeper, so each folds alone.
-- Levels are cached per changedtick; 'foldexpr' is called per line.
local notebook_folds = {} -- bufnr -> { tick, levels = { [line] = n } }

local function notebook_fold_levels(buf)
	local cached = notebook_folds[buf]
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	if cached and cached.tick == tick then
		return cached.levels
	end
	local levels = {}

	-- markdown cells
	local region_start = nil
	for line, text in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		if text:match('^%s*<!%-%-%s*#region') then
			region_start = line
		elseif text:match('^%s*<!%-%-%s*#endregion') and region_start then
			for l = region_start, line do
				levels[l] = 1
			end
			region_start = nil
		end
	end

	-- code cells
	local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
	for _, tree in ipairs(ok and parser and parser:parse() or {}) do
		local stack = { tree:root() }
		while #stack > 0 do
			local node = table.remove(stack)
			if node:type() == 'fenced_code_block' then
				local start_row, _, end_row = node:range() -- 0-based, end exclusive
				for line = start_row + 1, end_row do
					levels[line] = (levels[line] or 0) + 1
				end
			else
				for child in node:iter_children() do
					stack[#stack + 1] = child
				end
			end
		end
	end

	notebook_folds[buf] = { tick = tick, levels = levels }
	return levels
end

---Fold level of a line in a notebook (used as 'foldexpr').
function _G.NotebookFoldExpr(lnum)
	return notebook_fold_levels(vim.api.nvim_get_current_buf())[lnum] or 0
end

---Label of a folded cell (the global 'foldtext' is empty: highlight only, so a
---folded cell would otherwise be an invisible line).
function _G.NotebookFoldText()
	local first = vim.fn.getline(vim.v.foldstart)
	local count = vim.v.foldend - vim.v.foldstart + 1
	local lang = first:match('^%s*```%s*(%S*)')
	if lang then
		return string.format(' ╰─ %s ⋯ %d lines ', lang == '' and 'code' or lang, count)
	end
	return string.format(' ╰─ markdown ⋯ %d lines ', count)
end

-- Folding is on demand in notebook windows: foldenable is off globally, and
-- foldlevel 99 keeps the buffer unfolded until zc/za/zM.
local function notebook_fold_options(win)
	if win == nil or win == 0 or not vim.api.nvim_win_is_valid(win) then
		return
	end
	vim.wo[win].foldenable = true
	vim.wo[win].foldmethod = 'expr'
	vim.wo[win].foldlevel = 99
	vim.wo[win].foldexpr = 'v:lua.NotebookFoldExpr(v:lnum)'
	vim.wo[win].foldtext = 'v:lua.NotebookFoldText()'
end

-- Line range of the ```fence under the cursor, without the fence lines.
local function fenced_code_block_range()
	local ok, parser = pcall(vim.treesitter.get_parser, 0, 'markdown')
	if not ok or not parser then
		return nil
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2]
	local node = parser:parse()[1]:root():named_descendant_for_range(row - 1, col, row - 1, col)
	while node do
		if node:type() == 'fenced_code_block' then
			for child in node:iter_children() do
				if child:type() == 'code_fence_content' then
					-- MoltenEvaluateRange takes 1-based inclusive lines
					local start_row, _, end_row = child:range()
					return start_row + 1, end_row
				end
			end
			return nil -- empty block
		end
		node = node:parent()
	end
	return nil
end

vim.api.nvim_create_autocmd('FileType', {
	pattern = 'markdown',
	callback = function(args)
		-- Only notebooks: jupytext switches the buffer to markdown but the buffer
		-- keeps its *.ipynb name, so plain .md files don't pay for an otter raft.
		if not vim.api.nvim_buf_get_name(args.buf):match('%.ipynb$') then
			return
		end
		-- python only: without a list otter rafts every injected language in the
		-- document (yaml frontmatter / html comments get their own hidden buffers).
		require('otter').activate({ 'python' })

		notebook_fold_options(vim.api.nvim_get_current_win())
		-- jupytext sets the filetype from inside its BufReadCmd and this window is
		-- still being set up, so re-assert once the event loop is free. The project
		-- venv kernel is started in the same pass, so opening a notebook is enough
		-- (`,mv` remains as the explicit "(re)start from the venv" key).
		vim.schedule(function()
			for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
				notebook_fold_options(win)
			end
			if not vim.api.nvim_buf_is_valid(args.buf) or vim.bo[args.buf].buftype ~= '' then
				return -- oil previews and friends
			end
			if vim.fn.exists(':MoltenInit') == 0 then
				return -- molten not registered yet (:UpdateRemotePlugins)
			end
			local ok, running = pcall(vim.api.nvim_buf_call, args.buf, function()
				return vim.fn.MoltenStatusLineInit()
			end)
			if not ok or running ~= '' then
				return -- already has a kernel
			end
			local venv = project_venv(args.buf)
			local name = venv and venv_kernel_spec(venv, true)
			if name then
				vim.api.nvim_buf_call(args.buf, function()
					vim.cmd('MoltenInit ' .. name)
				end)
			end
		end)

		-- Run the whole ```block under the cursor (markdown has no `# %%` cells).
		vim.keymap.set('n', '<localleader>mb', function()
			local start_line, end_line = fenced_code_block_range()
			if not start_line then
				vim.notify('Notebook: no code block under the cursor', vim.log.levels.WARN)
				return
			end
			vim.fn.MoltenEvaluateRange(start_line, end_line)
		end, { buffer = args.buf, desc = 'Molten: run code block' })
	end,
})

-- Two upstream rough edges, both hit by real Colab/VS Code-exported notebooks:
--  * `metadata.kernelspec.language` is indexed unconditionally -> hard crash
--    ("attempt to index field 'kernelspec'") when there is no kernelspec;
--  * the default `output_extension = "auto"` makes the jupytext CLI derive the
--    script extension from `metadata.language_info.file_extension` or
--    `metadata.kernelspec.language`, and it *errors out* ("Please replace 'auto'
--    with the actual language extension") for notebooks that only carry
--    `language_info.name` / `kernelspec.name: python3` - which is exactly what
--    Colab exports look like, since they drop `language_info.file_extension`.
-- So parse the notebook once here, normalise language/extension, and pin
-- `output_extension` before the plugin builds its `--to=py:hydrogen` argument.
-- (The plugin uses that config field for the `--to` value, and takes the filetype
-- from what we return.) init.lua and commands.lua share these tables from the
-- require cache, so patching the fields reaches both.
local jupytext = require('jupytext')
local jupytext_utils = require('jupytext.utils')
local language_extensions = {
	python = 'py',
	julia = 'jl',
	r = 'r',
	bash = 'sh',
	cpp = 'cpp',
}
local kernelspec_names = { python3 = 'python' }

jupytext_utils.get_ipynb_metadata = function(filename)
	local ok, notebook = pcall(function()
		local file = assert(io.open(filename, 'r'))
		local text = file:read('a')
		file:close()
		return vim.json.decode(text)
	end)
	local metadata = (ok and notebook and notebook.metadata) or {}
	local kernelspec = metadata.kernelspec or {}
	local language_info = metadata.language_info or {}
	local language = kernelspec.language
		or language_info.name
		or kernelspec_names[kernelspec.name]
		or 'python'
	local extension = language_extensions[tostring(language):lower()]
		or (language_info.file_extension or ''):gsub('^%.', '')
	if extension == '' then
		extension = nil
	end
	-- "auto" would make the CLI re-derive it (and fail for the notebooks above)
	jupytext.config.output_extension = extension or 'auto'
	return { language = language, extension = extension }
end

-- require('codecompanion').setup({
-- 	-- adapters = {
-- 	-- 	http = {
-- 	-- 		ollama = function()
-- 	-- 			return require("codecompanion.adapters").extend("ollama", {
-- 	-- 				env = {
-- 	-- 					url = "https://llama.napatsc.com",
-- 	-- 					api_key = "ollama-lol",
-- 	-- 				},
-- 	-- 				headers = {
-- 	-- 					["Content-Type"] = "application/json",
-- 	-- 					-- ["Authorization"] = "Bearer ${api_key}",
-- 	-- 				},
-- 	-- 				parameters = {
-- 	-- 					sync = true,
-- 	-- 				},
-- 	-- 			})
-- 	-- 		end,
-- 	-- 	},
-- 	-- },
-- 	interactions = {
-- 		chat = {
-- 			adapter = "goose"
-- 			-- {
-- 			-- 	name = "ollama",
-- 			-- 	model = "openai/gpt-oss-20b"
-- 			-- }
-- 		}
-- 	}
-- })
