-- Completion, snippets and pair editing.

return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
    config = function(_, opts)
      local autopairs = require("nvim-autopairs")
      autopairs.setup(opts)
      autopairs.remove_rule("'")
      autopairs.remove_rule('"')
      autopairs.remove_rule("`")

    end,
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      {
        "L3MON4D3/LuaSnip",
        version = "2.*",
        dependencies = { "honza/vim-snippets" },
        config = function()
          local luasnip = require("luasnip")
          luasnip.config.setup({
            -- Leave the snippet once the cursor moves out of it, so <C-h>
            -- falls back to backspace instead of jumping back.
            region_check_events = "CursorMoved",
            delete_check_events = "TextChanged",
          })
          require("luasnip.loaders.from_snipmate").lazy_load()

          vim.keymap.set({ "i", "s" }, "<C-l>", function()
            if luasnip.jumpable(1) then
              luasnip.jump(1)
            end
          end, { silent = true, desc = "Snippet: next field" })
          vim.keymap.set({ "i", "s" }, "<C-h>", function()
            if luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              vim.api.nvim_feedkeys(vim.keycode("<BS>"), "n", false)
            end
          end, { silent = true, desc = "Snippet: previous field (or backspace)" })
        end,
      },
    },
    opts = {
      -- Same keys as before: <C-n>/<C-p> select, <C-y> accept, <C-Space>
      -- open, <C-e> close; plus <C-k> to toggle the signature.
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      -- Small windows keep the code visible: a short menu, documentation
      -- only after a pause and narrow enough to sit beside the menu, and a
      -- short signature. Noice leaves signature help to blink (no duplicate).
      completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        menu = {
          border = "rounded",
          max_height = 8,
          -- Kind names instead of Nerd Font icons when the font is missing.
          draw = not vim.g.have_nerd_font and {
            columns = { { "label", "label_description", gap = 1 }, { "kind" } },
          } or nil,
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 400,
          window = { border = "rounded", max_height = 12, desired_min_width = 30 },
        },
      },
      signature = { enabled = true, window = { border = "rounded", max_height = 4 } },
      snippets = { preset = "luasnip" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        -- vim-dadbod-completion is absent from the light profile (lang.lua).
        per_filetype = vim.g.vle_light and { lua = { inherit_defaults = true, "lazydev" } } or {
          lua = { inherit_defaults = true, "lazydev" },
          sql = { "dadbod", "snippets", "buffer" },
          mysql = { "dadbod", "snippets", "buffer" },
          plsql = { "dadbod", "snippets", "buffer" },
        },
        providers = {
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
        },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
  { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },
}
