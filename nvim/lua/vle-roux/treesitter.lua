local M = {}

M.parsers = {
  "bash",
  "c",
  "cmake",
  "cpp",
  "css",
  "fish",
  "glsl",
  "html",
  "javascript",
  "json",
  "lua",
  "make",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "sql",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

-- Light profile (NVIM_PROFILE=light): C, C++, Python and the languages of
-- Neovim's own files.
if vim.g.vle_light then
  M.parsers = {
    "bash",
    "c",
    "cpp",
    "lua",
    "make",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "vim",
    "vimdoc",
  }
end

-- Building parsers needs the tree-sitter CLI, which Mason installs
-- (see tools.lua). Without it, Neovim keeps its bundled parsers.
-- `opts.wait` (milliseconds) blocks until the parsers are built.
function M.install(opts)
  opts = opts or {}
  if vim.fn.executable("tree-sitter") ~= 1 then
    return false
  end

  local ok, treesitter = pcall(require, "nvim-treesitter")
  if not ok then
    return false
  end

  local installed = treesitter.get_installed()
  local missing = vim.tbl_filter(function(parser)
    return not vim.tbl_contains(installed, parser)
  end, M.parsers)
  if #missing > 0 then
    local task = treesitter.install(missing)
    if opts.wait then
      task:wait(opts.wait)
    end
  end
  return true
end

function M.setup()
  require("nvim-treesitter").setup({})
  M.install()

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("vle_treesitter", { clear = true }),
    callback = function(args)
      local language = vim.treesitter.language.get_lang(args.match)
      if not language or not pcall(vim.treesitter.start, args.buf, language) then
        return
      end

      if vim.api.nvim_get_current_buf() == args.buf then
        vim.wo[0][0].foldmethod = "expr"
        vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      end
    end,
    desc = "Start Treesitter highlighting and folding",
  })
end

function M.setup_textobjects()
  require("nvim-treesitter-textobjects").setup({
    select = { lookahead = true },
    move = { set_jumps = true },
  })

  local select = require("nvim-treesitter-textobjects.select")
  local move = require("nvim-treesitter-textobjects.move")

  local objects = {
    f = { "@function", "fonction" },
    c = { "@class", "classe / struct" },
    a = { "@parameter", "paramètre" },
    l = { "@loop", "boucle" },
    i = { "@conditional", "condition" },
  }

  for key, object in pairs(objects) do
    local capture, label = object[1], object[2]
    vim.keymap.set({ "x", "o" }, "a" .. key, function()
      select.select_textobject(capture .. ".outer", "textobjects")
    end, { desc = "Autour : " .. label })
    vim.keymap.set({ "x", "o" }, "i" .. key, function()
      select.select_textobject(capture .. ".inner", "textobjects")
    end, { desc = "Dans : " .. label })
  end

  -- ]c / [c stay free for diff hunks.
  local moves = {
    f = { "@function.outer", "fonction" },
    C = { "@class.outer", "classe / struct" },
  }
  for key, object in pairs(moves) do
    local capture, label = object[1], object[2]
    vim.keymap.set({ "n", "x", "o" }, "]" .. key, function()
      move.goto_next_start(capture, "textobjects")
    end, { desc = "Début de la " .. label .. " suivante" })
    vim.keymap.set({ "n", "x", "o" }, "[" .. key, function()
      move.goto_previous_start(capture, "textobjects")
    end, { desc = "Début de la " .. label .. " précédente" })
  end
end

return M
