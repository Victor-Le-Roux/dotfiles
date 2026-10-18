-- Treesitter, undo history, quickfix and sessions.

return {
  {
    -- The main branch does not support lazy-loading.
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("vle-roux.treesitter").setup()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("vle-roux.treesitter").setup_textobjects()
    end,
  },
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide" },
    keys = {
      { "<leader>u", "<Cmd>UndotreeToggle<CR>", desc = "Undo tree" },
    },
  },
  { "kevinhwang91/nvim-bqf", ft = "qf", opts = {} },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    keys = {
      {
        "<leader>sr",
        function()
          require("persistence").load()
        end,
        desc = "Restore session for this directory",
      },
      {
        "<leader>sl",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>sd",
        function()
          require("persistence").stop()
        end,
        desc = "Don't save this session",
      },
    },
    opts = {},
  },
}
