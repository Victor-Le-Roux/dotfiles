-- Language-specific extras and practice. GLSL, LaTeX and databases are
-- left out of the light profile (NVIM_PROFILE=light, C and Python only).

local full = not vim.g.vle_light

return {
  { "tikhomirov/vim-glsl", enabled = full, ft = { "glsl", "vert", "frag", "tesc", "tese", "geom", "comp" } },
  { "lervag/vimtex", enabled = full, ft = { "tex", "plaintex" } },
  {
    "kristijanhusak/vim-dadbod-ui",
    enabled = full,
    dependencies = {
      { "tpope/vim-dadbod", enabled = full, lazy = true },
      { "kristijanhusak/vim-dadbod-completion", enabled = full, ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = vim.g.have_nerd_font and 1 or 0
    end,
  },
  {
    "ThePrimeagen/vim-be-good",
    cmd = { "VimBeGood" },
    keys = {
      { "<leader>vg", "<Cmd>VimBeGood<CR>", desc = "Vim Be Good" },
    },
  },
}
