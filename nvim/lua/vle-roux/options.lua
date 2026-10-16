local options = {
  autoindent = true,
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
  incsearch = true,
  hlsearch = false,
  ignorecase = true,
  smartcase = true,

  splitbelow = true,
  splitright = true,

  termguicolors = true,
  hidden = true,
  signcolumn = "yes",
  showmode = false,
--  errorbells = false,
  wrap = true,
  linebreak = true,
  breakindent = true,
  cursorline = true,
  cursorlineopt = "number",
  fileencoding = "utf-8",

  backup = false,
  writebackup = false,
  swapfile = false,
  undofile = true, -- stored in stdpath("state")/undo

  -- Treesitter provides the folds; keep files unfolded when opened.
  foldlevelstart = 99,
  foldtext = "",

--  colorcolumn = "80",
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
  -- titlestring = "%t - Wvim",
  titlestring = "Neovim - %t",
  guifont = "JetBrainsMono Nerd Font Mono:h16",
  -- clipboard = "unnamedplus",
}

-- vim.opt.nrformats:append("alpha") -- increment letters
vim.opt.shortmess:append("IsF")

-- vim.o.shortmess = "filnxstToOFS"

for option, value in pairs(options) do
  vim.opt[option] = value
end

local fish = vim.fn.exepath("fish")
if fish ~= "" then
  vim.opt.shell = fish
end

-- .h files are C or C++ depending on their project: see c_tools.header_filetype.
