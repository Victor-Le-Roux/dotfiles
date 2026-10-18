-- Language-specific extras and practice.

return {
  { "tikhomirov/vim-glsl", ft = { "glsl", "vert", "frag", "tesc", "tese", "geom", "comp" } },
  { "lervag/vimtex", ft = { "tex", "plaintex" } },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
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
