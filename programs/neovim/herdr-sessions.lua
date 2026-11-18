-- Herdr editor restore.
--
-- Two halves, because herdr-core restores a pane as a *bare shell* in its last
-- folder and never re-runs the original command (see programs/herdr/default.nix):
--
--   1. resession keeps an nvim session per pane, saved when nvim exits and
--      reloaded when nvim starts with no file argument. This is what brings
--      buffers, splits and the cursor back. It cannot bring back unsaved text —
--      no session manager can, the process holding it is gone.
--   2. Every nvim running in a herdr terminal writes a `herdr.nvim` label with
--      its folder and parent shell pid. The zsh hook in
--      programs/shell/default.nix reads that label in each restored shell and
--      starts nvim again when the shell is a different process than the one
--      nvim ran under.
--
-- Sessions are keyed on "<terminal address>@<folder>", not on the folder alone:
-- several nvim panes can sit in one folder (nlp201 keeps three), and a
-- folder-keyed session means the last pane to quit overwrites the others. The
-- terminal address survives a reboot (t3x is still t3x), so each pane gets its
-- own session back; when there is none, loading falls back to the folder's
-- session, which is what a pane that did not exist before the restart sees.

local DIR = "dirsession"

local ok, resession = pcall(require, "resession")
if ok then
  resession.setup({
    autosave = { enabled = true, interval = 60, notify = false },
  })
end

-- "<address>@<folder>" in herdr, plain folder everywhere else
local function session_key()
  local cwd = vim.fn.getcwd()
  local terminal = vim.env.HC_TERMINAL_ID
  if terminal and terminal ~= "" then
    return terminal .. "@" .. cwd
  end
  return cwd
end

if ok then
  -- resession.load() on a name that has no session is a no-op, not an error,
  -- so existence has to be asked for explicitly — otherwise the folder fallback
  -- below would never run and a fresh pane would get an empty buffer.
  local function has_session(name)
    -- resession snapshots the name into a filename (slashes become "_"), so ask
    -- it for the path instead of comparing against resession.list(), which
    -- returns the encoded names and would never match a key like
    -- "t3x@/Users/…".
    local ok_util, util = pcall(require, "resession.util")
    if not ok_util then
      return false
    end
    local ok, path = pcall(util.get_session_file, name, DIR)
    return ok and path ~= nil and vim.uv.fs_stat(path) ~= nil
  end

  -- `nvim -` and similar stdin invocations must not autoload a session
  vim.api.nvim_create_autocmd("StdinReadPre", {
    callback = function()
      vim.g.using_stdin = true
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    nested = true,
    callback = function()
      if vim.fn.argc(-1) ~= 0 or vim.g.using_stdin then
        return
      end
      local key = session_key()
      local cwd = vim.fn.getcwd()
      if has_session(key) then
        pcall(resession.load, key, { dir = DIR, silence_errors = true })
      elseif key ~= cwd and has_session(cwd) then
        -- first start in a pane that has no session of its own yet
        pcall(resession.load, cwd, { dir = DIR, silence_errors = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      pcall(resession.save, session_key(), { dir = DIR, notify = false })
    end,
  })
end

-- Tell herdr this pane holds an editor, in which folder, and under which shell.
-- Detached: never blocks startup, and a missing hc is not an error.
local function note_terminal()
  local terminal = vim.env.HC_TERMINAL_ID
  if not terminal then
    return -- tmux, ssh, a plain terminal: nothing to restore later
  end
  local label = string.format(
    'herdr.nvim={"cwd":%s,"shell":%s}',
    vim.json.encode(vim.fn.getcwd()),
    tostring(vim.uv.os_getppid())
  )
  pcall(vim.fn.jobstart, { "hc", "label", terminal, label }, { detach = true })
end

vim.api.nvim_create_autocmd("VimEnter", { callback = note_terminal })
