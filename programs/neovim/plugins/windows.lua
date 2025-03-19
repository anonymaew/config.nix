local api = vim.api

-- Function to create and display the help in a floating window
local function open_help_in_floating_window()
    -- Open the help buffer normally
    vim.cmd('help')

    -- Get current buffer and winid for the opened help buffer
    local bufnr = api.nvim_get_current_buf()
    local winid = api.nvim_get_current_win()

    -- Create a floating window with the specified options
    local opts = {
        relative = 'editor',
        width = 80,
        height = 20,
        col = math.floor((vim.o.columns - 80) / 2),
        row = math.floor((vim.o.lines - 20) / 2),
        style = 'minimal'
    }

    -- Create the floating window
    local new_winid = api.nvim_open_win(bufnr, true, opts)

    -- Make sure the new window is focused
    api.nvim_set_current_win(new_winid)
end

-- Map :h to our custom function
api.nvim_create_user_command('H', open_help_in_floating_window, {})

-- Optionally map a key binding if you want to use it for quick access
vim.api.nvim_set_keymap('n', '<leader>hh', ':H<CR>', { noremap = true, silent = true })
