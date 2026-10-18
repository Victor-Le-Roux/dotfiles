local Remap = require("vle-roux.keymap")
local nnoremap = Remap.nnoremap
local inoremap = Remap.inoremap
local xnoremap = Remap.xnoremap
local tnoremap = Remap.tnoremap
local silent = { silent = true }

nnoremap("<leader>", "<Nop>", silent)
xnoremap("<leader>", "<Nop>", silent)

-- Movement
nnoremap("<C-L>", "<C-W><C-L>")
nnoremap("<C-H>", "<C-W><C-H>")
nnoremap("<C-K>", "<C-W><C-K>")
nnoremap("<C-J>", "<C-W><C-J>")
nnoremap("<C-d>", "<C-d>zz", { desc = "Half page down, centered" })
nnoremap("<C-u>", "<C-u>zz", { desc = "Half page up, centered" })
nnoremap("n", "nzzzv", { desc = "Next match, centered" })
nnoremap("N", "Nzzzv", { desc = "Previous match, centered" })
nnoremap("<C-f>", function()
  if vim.fn.executable("tmux") ~= 1 or not vim.env.TMUX then
    require("vle-roux.terminal").open()
    return
  end

  local cwd = vim.fn.getcwd()
  local sessionizer = vim.fn.expand("~/.local/bin/tmux-sessionizer")
  local command = { "tmux", "new-window", "-c", cwd }

  if vim.fn.executable(sessionizer) == 1 then
    table.insert(command, sessionizer)
  end

  vim.fn.jobstart(command, { detach = true })
end, { silent = true, desc = "New tmux window (or terminal split)" })
-- Visual * and # search the selection (built in since Neovim 0.10).
-- easy to quit insert mode
inoremap("jk", "<Esc>")
-- Copy Paste
xnoremap("<leader>y", "\"+y", { silent = true, desc = "Copy to system clipboard" })
-- <leader>d* is reserved for DAP in normal mode.
nnoremap("<leader>D", "\"_d", { desc = "Delete without yanking" })
xnoremap("<leader>d", "\"_d", { desc = "Delete without yanking" })

-- built in terminal
nnoremap("<leader>t", function()
  require("vle-roux.terminal").open()
end, { silent = true, desc = "Open terminal split" })
tnoremap("<C-h>", function()
  vim.cmd("wincmd h")
end, { silent = true, desc = "Terminal: left window" })
tnoremap("<C-l>", function()
  vim.cmd("wincmd l")
end, { silent = true, desc = "Terminal: right window" })
tnoremap("<C-j>", function()
  vim.cmd("wincmd j")
end, { silent = true, desc = "Terminal: lower window" })
tnoremap("<C-k>", function()
  vim.cmd("wincmd k")
end, { silent = true, desc = "Terminal: upper window" })
tnoremap("<C-x>", "<C-\\><C-n>", { silent = true, desc = "Terminal normal mode" })
tnoremap("<C-q>", function()
  vim.api.nvim_buf_delete(0, { force = true })
end, { silent = true, desc = "Close terminal" })
-- nnoremap("<leader>cb", "<Cmd>make<CR>")
-- tnoremap("<D-v>", function()
--   local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>\"+pi", true, false, true)
--   vim.api.nvim_feedkeys(keys, "n", false)
-- end, silent)

-- misc
nnoremap("<leader>rp", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>", { desc = "Replace word under cursor" })
nnoremap("<leader>w", "<Cmd>w<CR>", { desc = "Write" })
nnoremap("<leader>q", "<Cmd>confirm q<CR>", { desc = "Quit, asking before discarding changes" })
nnoremap("<leader>Q", "<Cmd>wq<CR>", { desc = "Write and quit" })
nnoremap("<leader>vm", "<Cmd>MarkdownPreview<CR>", { silent = true, desc = "Toggle Markdown preview" })
nnoremap("<leader>vM", "<Cmd>MarkdownPreviewRefresh<CR>", { silent = true, desc = "Refresh Markdown preview" })
-- nnoremap("<leader><C-o>", "<Cmd>!open %<CR><CR>", silent)
nnoremap("J", "mzJ`z", { desc = "Join lines, keep cursor" })
xnoremap("J", "mzJ`z")
nnoremap("<leader>cb", "<Cmd>Build<CR>", { silent = true, desc = "Build project" })
nnoremap("<leader>cc", "<Cmd>CConfigure<CR>", { silent = true, desc = "Configure CMake project" })
nnoremap("<leader>ct", "<Cmd>CTest<CR>", { silent = true, desc = "Run CTest" })
-- crun is a fish function; without fish (42 workstations), :Ha builds then runs.
nnoremap("<leader>cr", function()
  if vim.fn.executable("fish") ~= 1 then
    vim.cmd("Ha")
    return
  end
  require("vle-roux.terminal").open({ "fish", "-c", "crun" }, 20)
end, { silent = true, desc = "Compiler et lancer le projet" })
nnoremap("<leader>co", "<Cmd>OverseerToggle<CR>", { silent = true, desc = "Toggle task list" })
nnoremap("<leader>cR", "<Cmd>OverseerRun<CR>", { silent = true, desc = "Run a task (make re, valgrind, norminette...)" })
nnoremap("<leader>cB", "<Cmd>CBear<CR>", { silent = true, desc = "Generate compile_commands.json with bear" })
nnoremap("<leader>cn", "<Cmd>Norm42<CR>", { silent = true, desc = "Toggle 42 norm for this buffer" })

inoremap("<Down>", "<Nop>")
inoremap("<Left>", "<Nop>")
inoremap("<Right>", "<Nop>")
inoremap("<Up>", "<Nop>")

nnoremap("<Down>", "<Nop>")
nnoremap("<Left>", "<Nop>")
nnoremap("<Right>", "<Nop>")
nnoremap("<Up>", "<Nop>")

xnoremap("<Down>", "<Nop>")
xnoremap("<Left>", "<Nop>")
xnoremap("<Right>", "<Nop>")
xnoremap("<Up>", "<Nop>")
