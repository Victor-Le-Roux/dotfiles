 local options = {
   autoindent = true,
   smartindent = true,
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
   undodir = os.getenv("HOME") .. "/.vim/undodir",
   undofile = true,
 
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

vim.g.skip_ts_context_commentstring_module = true

-- The built-in C syntax leaves function names unstyled unless this is enabled.
-- clangd may refine them later through semantic highlighting.
vim.g.c_functions = true
