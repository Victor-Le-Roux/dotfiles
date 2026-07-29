local Remap = require("vle-roux.keymap")
local nnoremap = Remap.nnoremap
local inoremap = Remap.inoremap
local xnoremap = Remap.xnoremap
local vnoremap = Remap.xnoremap
local tnoremap = Remap.tnoremap

nnoremap("<leader>", "<Nop>", silent)
vnoremap("<leader>", "<Nop>", silent)

-- Movement
nnoremap("<C-L>", "<C-W><C-L>")
nnoremap("<C-H>", "<C-W><C-H>")
nnoremap("<C-K>", "<C-W><C-K>")
nnoremap("<C-J>", "<C-W><C-J>")
nnoremap("<C-d>", "<C-d>zz")
nnoremap("<C-u>", "<C-u>zz")
nnoremap("n", "nzzzv")
nnoremap("N", "Nzzzv")
nnoremap("<C-f>", function()
  if vim.fn.executable("tmux") ~= 1 or not vim.env.TMUX then
    vim.cmd("botright split | terminal")
    vim.cmd("resize 15")
    vim.cmd("startinsert")
    return
  end

  local cwd = vim.fn.getcwd()
  local sessionizer = vim.fn.expand("~/.local/bin/tmux-sessionizer")
  local command = { "tmux", "new-window", "-c", cwd }

  if vim.fn.executable(sessionizer) == 1 then
    table.insert(command, sessionizer)
  end

  vim.fn.jobstart(command, { detach = true })
end, { silent = true })
xnoremap(
  "n",
  [[:<c-u>let temp_variable=@"<CR>gvy:<c-u>let @/='\V<C-R>=escape(@",'/\')<CR>'<CR>:let @"=temp_variable<CR>]],
  silent
)
-- easy to quit insert mode
inoremap("jk", "<Esc>")
-- Copy Paste
xnoremap("<leader>y", "\"+y", silent)
nnoremap("<leader>d", "\"_d")
xnoremap("<leader>d", "\"_d")

-- built in terminal
nnoremap("<leader>t", "<Cmd>sp<CR> <Cmd>term<CR> <Cmd>resize 15N<CR> i", silent)
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
nnoremap("<leader>rp", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>")
nnoremap("<leader>w", "<Cmd>w<CR>")
nnoremap("<leader>q", "<Cmd>q!<CR>")
nnoremap("<leader>wq", "<Cmd>wq<CR>")
nnoremap("<leader>vm", "<Cmd>MarkdownPreview<CR>", { silent = true, desc = "Toggle Markdown preview" })
nnoremap("<leader>vM", "<Cmd>MarkdownPreviewRefresh<CR>", { silent = true, desc = "Refresh Markdown preview" })
-- nnoremap("<leader><C-o>", "<Cmd>!open %<CR><CR>", silent)
nnoremap("J", "mzJ`z")
xnoremap("J", "mzJ`z")
nnoremap("<leader>cb", "<Cmd>Build<CR>", { silent = true, desc = "Build project" })
nnoremap("<leader>cc", "<Cmd>CConfigure<CR>", { silent = true, desc = "Configure CMake project" })
nnoremap("<leader>ct", "<Cmd>CTest<CR>", { silent = true, desc = "Run CTest" })
nnoremap("<leader>cr", "<Cmd>Run<CR>", { silent = true, desc = "Run program" })
nnoremap("<leader>co", "<Cmd>OverseerToggle<CR>", { silent = true, desc = "Toggle task list" })

inoremap("<Down>", "<Nop>")
inoremap("<Left>", "<Nop>")
inoremap("<Right>", "<Nop>")
inoremap("<Up>", "<Nop>")

nnoremap("<Down>", "<Nop>")
nnoremap("<Left>", "<Nop>")
nnoremap("<Right>", "<Nop>")
nnoremap("<Up>", "<Nop>")

vnoremap("<Down>", "<Nop>")
vnoremap("<Left>", "<Nop>")
vnoremap("<Right>", "<Nop>")
vnoremap("<Up>", "<Nop>")
