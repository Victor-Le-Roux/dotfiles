local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

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

require("lazy").setup({
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "williamboman/mason.nvim" },
      { "williamboman/mason-lspconfig.nvim" },
      { "jay-babu/mason-nvim-dap.nvim" },
      { "nvimtools/none-ls.nvim" },
      { "jay-babu/mason-null-ls.nvim" },
      { "hrsh7th/nvim-cmp" },
      { "hrsh7th/cmp-buffer" },
      { "hrsh7th/cmp-path" },
      { "saadparwaiz1/cmp_luasnip" },
      { "hrsh7th/cmp-nvim-lsp" },
      { "hrsh7th/cmp-nvim-lua" },
      { "L3MON4D3/LuaSnip", version = "2.*" },
      { "honza/vim-snippets" },
    },
    config = function()
      local Remap = require("vle-roux.keymap")
      local inoremap = Remap.inoremap
      local nnoremap = Remap.nnoremap
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local mason_lspconfig = require("mason-lspconfig")
      local cmp = require("cmp")

      local format_servers = {
        gopls = { go = true },
        pylsp = { python = true },
        clangd = { cpp = true, c = true },
        ["null-ls"] = {
          lua = true,
          json = true,
          javascript = true,
          typescript = true,
          typescriptreact = true,
          markdown = true,
          css = true,
          sass = true,
          scss = true,
          txt = true,
          text = true,
          html = true,
          tex = true,
          haskell = true,
          plaintex = true,
        },
      }

      local function has_format_rule(filetype)
        for _, rules in pairs(format_servers) do
          if rules[filetype] then
            return true
          end
        end
        return false
      end

      local function on_attach(_, bufnr)
        local opts = { buffer = bufnr, silent = true }

        nnoremap("<leader>.", vim.lsp.buf.code_action, opts)
        nnoremap("<leader>rn", vim.lsp.buf.rename, opts)
        nnoremap("<leader>fi", vim.lsp.buf.implementation, opts)
        nnoremap("<leader>fr", vim.lsp.buf.references, opts)
        nnoremap("<leader>ff", vim.lsp.buf.definition, opts)
        nnoremap("<leader>fF", vim.lsp.buf.declaration, opts)
        nnoremap("K", vim.lsp.buf.hover, opts)
        inoremap("<C-h>", vim.lsp.buf.signature_help, opts)
        inoremap("<C-j>", vim.lsp.buf.signature_help, opts)
        nnoremap("<leader>,", vim.diagnostic.setloclist, opts)
        nnoremap("<leader>m", function()
          local filetype = vim.bo[bufnr].filetype
          local with_filter = has_format_rule(filetype)
          vim.lsp.buf.format({
            bufnr = bufnr,
            async = false,
            timeout_ms = 10000,
            filter = with_filter and function(client)
              local rules = format_servers[client.name]
              return rules and rules[filetype] or false
            end or nil,
          })
        end, opts)
      end

      local clangd_capabilities = vim.tbl_deep_extend("force", capabilities, {
        offsetEncoding = "utf-8",
        offset_encoding = "utf-8",
      })

      vim.lsp.config("*", {
        on_attach = on_attach,
        capabilities = capabilities,
      })
      vim.lsp.config("clangd", {
        on_attach = on_attach,
        capabilities = clangd_capabilities,
      })

      require("mason").setup()
      mason_lspconfig.setup({
        ensure_installed = { "clangd" },
        automatic_enable = false,
      })

      for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        vim.lsp.enable(server_name)
      end

      require("mason-nvim-dap").setup({
        ensure_installed = { "python", "codelldb" },
        automatic_installation = true,
        handlers = {
          function(config)
            require("mason-nvim-dap").default_setup(config)
          end,
        },
      })

      local cmp_select = { behavior = cmp.SelectBehavior.Select }

      cmp.setup({
        performance = {
          debounce = 0,
          throttle = 0,
          confirm_resolve_timeout = 0,
        },
        preselect = cmp.PreselectMode.None,
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
          ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
          ["<C-y>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "nvim_lua" },
          { name = "buffer" },
          { name = "path" },
        },
        window = {
          completion = { border = "rounded" },
          documentation = { border = "rounded" },
        },
      })

      local null_ls = require("null-ls")

      local txt_formatter = {
        method = null_ls.methods.FORMATTING,
        filetypes = { "txt", "text" },
        generator = null_ls.formatter({
          command = "txt-format",
          args = { "$FILENAME" },
          to_stdin = true,
          from_stderr = true,
        }),
      }

      null_ls.setup({
        on_attach = on_attach,
        sources = { txt_formatter },
      })

      require("mason-null-ls").setup({
        ensure_installed = nil,
        automatic_installation = false,
        handlers = {},
      })
    end,
  },

  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
    opts = function()
      local ok_setup, ts_context_commentstring_core = pcall(require, "ts_context_commentstring")
      if ok_setup then
        ts_context_commentstring_core.setup({})
      end

      local ok, ts_context_commentstring = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
      if ok then
        return { pre_hook = ts_context_commentstring.create_pre_hook() }
      end
      return {}
    end,
  },
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

      local ok_cmp, cmp = pcall(require, "cmp")
      if ok_cmp then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end,
  },
  { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      { "windwp/nvim-ts-autotag" },
      { "nvim-treesitter/nvim-treesitter-context" },
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "c", "cpp", "markdown", "markdown_inline" },
        highlight = { enable = true },
        indent = { enable = true },
        autotag = { enable = true },
      })
      require("treesitter-context").setup({})
    end,
  },
  { "tikhomirov/vim-glsl", ft = { "glsl", "vert", "frag", "tesc", "tese", "geom", "comp" } },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle", "NvimTreeCollapse" },
    keys = {
      { "<leader><tab>", "<Cmd>NvimTreeToggle<CR>" },
      { "<leader>f<tab>", "<Cmd>NvimTreeFindFileToggle<CR>" },
      { "<leader>z", "<Cmd>NvimTreeCollapse<CR>" },
    },
    dependencies = { { "nvim-tree/nvim-web-devicons" } },
    config = function()
      local function my_on_attach(bufnr)
        local api = require("nvim-tree.api")
        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.set("n", "z", api.tree.change_root_to_node, opts("CD"))
      end

      require("nvim-tree").setup({
        on_attach = my_on_attach,
        view = {
          float = {
            enable = true,
            open_win_config = {
              width = math.floor(vim.o.columns * 0.8),
              height = vim.o.lines - 6,
              row = 2,
              col = math.floor(vim.o.columns * 0.1),
            },
          },
        },
        actions = { open_file = { quit_on_open = true } },
        filters = { dotfiles = false, custom = { "^.DS_Store$", "^\\.git$" } },
        git = { enable = true, ignore = false, timeout = 500 },
      })
    end,
  },
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    keys = {
      {
        "<leader>a",
        function()
          require("harpoon"):list():append()
        end,
      },
      {
        "<leader>e",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
      },
      {
        "<leader>1",
        function()
          require("harpoon"):list():select(1)
        end,
      },
      {
        "<leader>2",
        function()
          require("harpoon"):list():select(2)
        end,
      },
      {
        "<leader>3",
        function()
          require("harpoon"):list():select(3)
        end,
      },
      {
        "<leader>4",
        function()
          require("harpoon"):list():select(4)
        end,
      },
      {
        "<leader>5",
        function()
          require("harpoon"):list():select(5)
        end,
      },
      {
        "<leader>6",
        function()
          require("harpoon"):list():select(6)
        end,
      },
      {
        "<leader>7",
        function()
          require("harpoon"):list():select(7)
        end,
      },
      {
        "<leader>8",
        function()
          require("harpoon"):list():select(8)
        end,
      },
      {
        "<leader>9",
        function()
          require("harpoon"):list():select(9)
        end,
      },
      {
        "<leader>0",
        function()
          require("harpoon"):list():select(10)
        end,
      },
    },
    config = function()
      local harpoon = require("harpoon")

      local function sync(evt, list)
        local file = evt.file
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row, col = cursor[1], cursor[2]

        for _, item in pairs(list.items) do
          local relative = vim.loop.cwd() .. "/" .. item.value
          if relative == file then
            item.context = { row = row, col = col }
          end
        end
      end

      harpoon:setup({
        default = {
          save_on_toggle = true,
          sync_on_ui_close = true,
          BufLeave = sync,
          VimLeavePre = sync,
        },
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    cmd = { "Telescope" },
    keys = {
      {
        "<leader>p",
        function()
          require("telescope.builtin").find_files()
        end,
      },
      {
        "<leader>x",
        function()
          require("telescope.builtin").live_grep()
        end,
      },
      {
        "<leader>b",
        function()
          require("telescope.builtin").buffers()
        end,
      },
    },
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      { "kdheepak/lazygit.nvim" },
    },
    config = function()
      local telescope = require("telescope")

      telescope.setup({
        defaults = {
          layout_config = {
            width = 0.85,
            preview_cutoff = 120,
            horizontal = {
              preview_width = function(_, cols)
                if cols < 120 then
                  return math.floor(cols * 0.5)
                end
                return math.floor(cols * 0.6)
              end,
              mirror = false,
            },
            vertical = { mirror = false },
          },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
          },
          file_ignore_patterns = {
            "node_modules/",
            "%.git/",
            "%.DS_Store$",
            "target/",
            "build/",
            "%.o$",
          },
          winblend = 0,
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          color_devicons = true,
          set_env = { ["COLORTERM"] = "truecolor" },
        },
        pickers = {
          find_files = { hidden = true },
          live_grep = { only_sort_text = true },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "lazygit")
      pcall(telescope.load_extension, "noice")
    end,
  },
  {
    "nvim-telescope/telescope-dap.nvim",
    dependencies = { "mfussenegger/nvim-dap", "nvim-telescope/telescope.nvim" },
    cmd = { "Telescope" },
  },

  { "lewis6991/gitsigns.nvim", event = { "BufReadPre", "BufNewFile" }, opts = {} },
  {
    "mfussenegger/nvim-dap",
    cmd = {
      "DapContinue",
      "DapToggleBreakpoint",
      "DapStepOver",
      "DapStepInto",
      "DapStepOut",
      "DapTerminate",
      "DapRunToCursor",
      "DapClearBreakpoints",
    },
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap" },
    cmd = { "DapUIOpen", "DapUIClose", "DapUIToggle" },
  },

  { "kevinhwang91/nvim-bqf", ft = "qf", opts = {} },
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide" },
    keys = {
      { "<leader>u", "<Cmd>UndotreeToggle<CR>" },
    },
  },
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
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },

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
      },
      presets = {
        long_message_to_split = false,
      },
      routes = {
        {
          filter = {
            event = "notify",
            find = "context_commentstring nvim%-treesitter module is deprecated",
          },
          opts = { skip = true },
        },
      },
    },
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      render = "compact",
      timeout = 3000,
      max_width = function()
        return math.floor(vim.o.columns * 0.4)
      end,
      max_height = function()
        return math.floor(vim.o.lines * 0.2)
      end,
    },
  },
  {
    "m4xshen/hardtime.nvim",
    event = "VeryLazy",
    dependencies = {
      { "MunifTanjim/nui.nvim" },
    },
    opts = {},
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
    "ThePrimeagen/vim-be-good",
    cmd = { "VimBeGood" },
    keys = {
      { "<leader>vg", "<Cmd>VimBeGood<CR>", desc = "Vim Be Good" },
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
          theme = "auto",
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
          lualine_x = { "encoding", "filetype" },
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
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
}, {
  change_detection = {
    notify = false,
  },
})
