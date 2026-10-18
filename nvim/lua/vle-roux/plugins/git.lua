-- Git signs, hunks and diff views.

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
        end

        map("n", "]h", function()
          gitsigns.nav_hunk("next")
        end, "Next git hunk")
        map("n", "[h", function()
          gitsigns.nav_hunk("prev")
        end, "Previous git hunk")
        map("n", "<leader>gp", gitsigns.preview_hunk, "Preview hunk")
        map("n", "<leader>gs", gitsigns.stage_hunk, "Stage / unstage hunk")
        map("x", "<leader>gs", function()
          gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage / unstage selection")
        map("n", "<leader>gr", gitsigns.reset_hunk, "Reset hunk")
        map("n", "<leader>gS", gitsigns.stage_buffer, "Stage buffer")
        map("n", "<leader>gb", function()
          gitsigns.blame_line({ full = true })
        end, "Blame line")
        map("n", "<leader>gd", gitsigns.diffthis, "Diff against index")
        map({ "o", "x" }, "ih", gitsigns.select_hunk, "Inside git hunk")
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gv", "<Cmd>DiffviewOpen<CR>", desc = "Diff view (working tree)" },
      { "<leader>gV", "<Cmd>DiffviewFileHistory %<CR>", desc = "File history" },
      { "<leader>gq", "<Cmd>DiffviewClose<CR>", desc = "Close diff view" },
    },
    opts = {},
  },
}
