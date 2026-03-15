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
  if not vim.env.TMUX then
    vim.notify("tmux not detected", vim.log.levels.WARN)
    return
  end
  local cwd = vim.fn.getcwd()
  vim.fn.jobstart({ "tmux", "new-window", "-c", cwd, "/home/victor/.local/bin/tmux-sessionizer" }, { detach = true })
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
tnoremap("<C-c><C-c>", "<C-\\><C-n>", silent)
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
tnoremap("<Esc><Esc>", "<C-\\><C-n>")
local function find_project_root()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = vim.loop.cwd()
  end

  local markers = { "Makefile", "makefile", "compile_commands.json", "CMakeLists.txt", ".git" }
  local found = vim.fs.find(markers, { path = path, upward = true })
  if #found == 0 then
    return vim.loop.cwd()
  end

  return vim.fs.dirname(found[1])
end

nnoremap("<leader>cb", function()
  local root = find_project_root()
  vim.cmd("lcd " .. vim.fn.fnameescape(root))
  vim.cmd("make")
  vim.cmd("botright cwindow")
end)

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
