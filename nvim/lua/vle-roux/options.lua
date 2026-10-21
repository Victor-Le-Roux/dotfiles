local options = {
  -- No smartindent: filetype indent handles C and Python, and smartindent
  -- would push Python "#" comments to column 0.
  expandtab = false,
  tabstop = 4,
  softtabstop = 4,
  shiftwidth = 4,
  list = true,
  showtabline = 0,

  number = true,
  relativenumber = true,
  numberwidth = 4,
  hlsearch = false,
  ignorecase = true,
  smartcase = true,

  splitbelow = true,
  splitright = true,

  termguicolors = true,
  signcolumn = "yes",
  showmode = false,
  wrap = true,
  linebreak = true,
  breakindent = true,
  cursorline = true,
  cursorlineopt = "number",

  backup = false,
  writebackup = false,
  swapfile = false,
  undofile = true, -- stored in stdpath("state")/undo

  -- Treesitter provides the folds; keep files unfolded when opened.
  foldlevelstart = 99,
  foldtext = "",

  updatetime = 250,
  scrolloff = 15,
  mouse = "",
  guicursor = "a:block",

  listchars = {
    tab = "→ ",
    space = "·",
    trail = "×",
    nbsp = "␣",
  },

  title = true,
  titlestring = "Neovim - %t",
  guifont = "JetBrainsMono Nerd Font Mono:h16",
}

vim.opt.shortmess:append("IsF")

-- Icons need a Nerd Font in the terminal. NVIM_NERD_FONT=0 switches the
-- plugins to plain text (a terminal without the font, e.g. at 42).
vim.g.have_nerd_font = vim.env.NVIM_NERD_FONT ~= "0"

-- NVIM_PROFILE=light keeps only the C and Python tools (machines with a
-- small home quota, e.g. 42 sessions): see tools.lua and treesitter.lua.
vim.g.vle_light = vim.env.NVIM_PROFILE == "light"

for option, value in pairs(options) do
  vim.opt[option] = value
end

-- fish as 'shell' slows system() and :! and trips some plugins: it only
-- runs in terminals (see terminal.lua).
if vim.o.shell:match("fish$") then
  vim.o.shell = "sh"
end

-- .h files are C or C++ depending on their project: see c_tools.header_filetype.
