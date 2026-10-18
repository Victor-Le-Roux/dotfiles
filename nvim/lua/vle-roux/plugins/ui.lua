-- Interface: messages, statusline, guides, hints and the colorscheme.

local function lualine_word_count()
  if vim.fn.getfsize(vim.fn.expand("%")) > 200000 then
    return ""
  end

  local words = vim.fn.wordcount()
  local count = words.visual_words or words.words or 0
  if count == 1 then
    return "1 word"
  end
  return tostring(count) .. " words"
end

local function visual_selection_active()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

local function lualine_visual_char_count()
  local count = vim.fn.wordcount().visual_chars or 0
  return tostring(count)
end

return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      { "MunifTanjim/nui.nvim" },
      { "rcarriga/nvim-notify" },
      { "nvim-lua/plenary.nvim" },
    },
    opts = {
      lsp = {
        progress = { enabled = false },
        -- blink.cmp shows signature help and follows window resizes.
        signature = { enabled = false },
      },
      presets = {
        long_message_to_split = false,
      },
      cmdline = vim.g.have_nerd_font and {} or {
        format = {
          cmdline = { icon = ":" },
          search_down = { icon = "/" },
          search_up = { icon = "?" },
          filter = { icon = "$" },
          lua = { icon = "lua" },
          help = { icon = "?" },
        },
      },
    },
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      render = "compact",
      timeout = 3000,
      icons = vim.g.have_nerd_font and nil or {
        ERROR = "E",
        WARN = "W",
        INFO = "I",
        DEBUG = "D",
        TRACE = "T",
      },
      max_width = function()
        return math.floor(vim.o.columns * 0.4)
      end,
      max_height = function()
        return math.floor(vim.o.lines * 0.2)
      end,
    },
  },
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    cmd = { "Precognition" },
    keys = {
      {
        "<leader>vp",
        function()
          require("precognition").toggle()
        end,
        desc = "Toggle Precognition",
      },
      { "<leader>vP", "<Cmd>Precognition peek<CR>", desc = "Peek Precognition" },
    },
    opts = {
      startVisible = true,
      showBlankVirtLine = false,
      highlightColor = { link = "Comment" },
      disabled_fts = { "NvimTree", "lazy", "mason", "help", "qf", "TelescopePrompt" },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      return {
        options = {
          globalstatus = true,
          icons_enabled = vim.g.have_nerd_font,
          theme = "estampe",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = {
            "filename",
            {
              lualine_word_count,
              cond = function()
                return vim.g.vle_word_count_enabled
              end,
            },
          },
          lualine_x = {
            {
              lualine_visual_char_count,
              cond = visual_selection_active,
            },
            "encoding",
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    keys = {
      { "<leader>,", "<Cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
      { "<leader>;", "<Cmd>Trouble diagnostics toggle<CR>", desc = "Project diagnostics" },
      { "<leader>fq", "<Cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
    },
    opts = {},
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      icons = { mappings = vim.g.have_nerd_font },
      spec = {
        { "<leader>c", group = "C / build" },
        { "<leader>d", group = "Debug" },
        { "<leader>f", group = "Find / LSP" },
        { "<leader>fc", group = "Calls" },
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Harpoon" },
        { "<leader>i", group = "REPL Python" },
        { "<leader>n", group = "Tests" },
        { "<leader>r", group = "Rename / replace" },
        { "<leader>s", group = "Session" },
        { "<leader>v", group = "View / toggles" },
      },
    },
  },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
}
