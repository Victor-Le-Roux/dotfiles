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

local function visual_selection_active()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

local function lualine_visual_char_count()
  local count = vim.fn.wordcount().visual_chars or 0
  return tostring(count)
end

local function switch_source_header(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })[1]
  local method = "textDocument/switchSourceHeader"
  if not client or not client:supports_method(method) then
    vim.notify("clangd ne prend pas en charge le passage source/en-tête", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_text_document_params(bufnr)
  client:request(method, params, function(err, result)
    if err then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      return
    end
    if not result then
      vim.notify("Aucun fichier source/en-tête correspondant", vim.log.levels.WARN)
      return
    end
    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr)
end

require("lazy").setup({
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonUpdate", "MasonInstall", "MasonUninstall" },
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "williamboman/mason.nvim" },
      { "williamboman/mason-lspconfig.nvim" },
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
        nnoremap("<leader>fs", "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>", opts)
        nnoremap("<leader>fd", "<Cmd>Telescope diagnostics bufnr=0<CR>", opts)
        nnoremap("<leader>fh", function()
          switch_source_header(bufnr)
        end, opts)
        nnoremap("<leader>fci", vim.lsp.buf.incoming_calls, opts)
        nnoremap("<leader>fco", vim.lsp.buf.outgoing_calls, opts)
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
        offsetEncoding = { "utf-8", "utf-16" },
        offset_encoding = { "utf-8", "utf-16" },
      })

      vim.lsp.config("*", {
        on_attach = on_attach,
        capabilities = capabilities,
      })
      vim.lsp.config("clangd", {
        cmd = {
          require("vle-roux.c_tools").clangd_command(),
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
        },
        root_markers = {
          ".clangd",
          ".clang-tidy",
          ".clang-format",
          "compile_commands.json",
          "compile_flags.txt",
          "CMakePresets.json",
          "CMakeLists.txt",
          "Makefile",
          "makefile",
          ".git",
        },
        on_attach = on_attach,
        capabilities = clangd_capabilities,
      })

      mason_lspconfig.setup({
        ensure_installed = {},
        automatic_enable = false,
      })

      local enabled_servers = {}
      for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        enabled_servers[server_name] = true
      end
      for server_name, executable in pairs({ clangd = "clangd", gopls = "gopls", pylsp = "pylsp" }) do
        if vim.fn.executable(executable) == 1 then
          enabled_servers[server_name] = true
        end
      end
      for server_name in pairs(enabled_servers) do
        vim.lsp.enable(server_name)
      end

      local cmp_select = { behavior = cmp.SelectBehavior.Select }

      cmp.setup({
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

      local null_sources = {}
      if vim.fn.executable("txt-format") == 1 then
        table.insert(null_sources, txt_formatter)
      end

      null_ls.setup({
        on_attach = on_attach,
        sources = null_sources,
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
        ts_context_commentstring_core.setup({
          enable_autocmd = false,
        })
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
  { "tikhomirov/vim-glsl", ft = { "glsl", "vert", "frag", "tesc", "tese", "geom", "comp" } },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle", "NvimTreeCollapse" },
    keys = {
      { "<leader><tab>", "<Cmd>NvimTreeToggle<CR>" },
      { "<leader>f<tab>", "<Cmd>NvimTreeFindFile!<CR>" },
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
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>a",
        function()
          require("harpoon"):list():add()
        end,
        desc = "Harpoon add file",
      },
      {
        "<leader>e",
        function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "Harpoon menu",
      },
      {
        "<leader>1",
        function()
          require("harpoon"):list():select(1)
        end,
        desc = "Harpoon file 1",
      },
      {
        "<leader>2",
        function()
          require("harpoon"):list():select(2)
        end,
        desc = "Harpoon file 2",
      },
      {
        "<leader>3",
        function()
          require("harpoon"):list():select(3)
        end,
        desc = "Harpoon file 3",
      },
      {
        "<leader>4",
        function()
          require("harpoon"):list():select(4)
        end,
        desc = "Harpoon file 4",
      },
      {
        "<leader>5",
        function()
          require("harpoon"):list():select(5)
        end,
        desc = "Harpoon file 5",
      },
      {
        "<leader>6",
        function()
          require("harpoon"):list():select(6)
        end,
        desc = "Harpoon file 6",
      },
      {
        "<leader>7",
        function()
          require("harpoon"):list():select(7)
        end,
        desc = "Harpoon file 7",
      },
      {
        "<leader>8",
        function()
          require("harpoon"):list():select(8)
        end,
        desc = "Harpoon file 8",
      },
      {
        "<leader>9",
        function()
          require("harpoon"):list():select(9)
        end,
        desc = "Harpoon file 9",
      },
      {
        "<leader>0",
        function()
          require("harpoon"):list():select(10)
        end,
        desc = "Harpoon file 10",
      },
      {
        "<leader>hn",
        function()
          require("harpoon"):list():next()
        end,
        desc = "Harpoon next file",
      },
      {
        "<leader>hp",
        function()
          require("harpoon"):list():prev()
        end,
        desc = "Harpoon previous file",
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
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
        },
        default = {
          BufLeave = sync,
          VimLeavePre = sync,
        },
      })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    cmd = { "Telescope" },
    init = function()
      local group = vim.api.nvim_create_augroup("vle_startup_file_picker", { clear = true })

      local function allowed_directories()
        local directories = {}
        local seen = {}

        for _, path in ipairs(vim.split(vim.env.NVIM_SEARCH_DIRS or "", ":", { plain = true, trimempty = true })) do
          path = vim.fs.normalize(vim.fn.expand(path))
          if vim.fn.isdirectory(path) == 1 and not seen[path] then
            seen[path] = true
            directories[#directories + 1] = path
          end
        end

        return directories
      end

      local function is_allowed(path, roots)
        path = vim.fs.normalize(path)
        for _, root in ipairs(roots) do
          if root == "/" or path == root or vim.startswith(path, root .. "/") then
            return true
          end
        end
        return false
      end

      local function open_allowed_files(directories)
        require("lazy").load({ plugins = { "telescope.nvim" } })

        local options = { hidden = true, prompt_title = "Dossiers autorisés" }
        if #directories == 1 then
          options.cwd = directories[1]
        else
          options.find_command = { "find" }
          vim.list_extend(options.find_command, directories)
          vim.list_extend(options.find_command, {
            "-type",
            "d",
            "(",
            "-name",
            ".git",
            "-o",
            "-name",
            "node_modules",
            "-o",
            "-name",
            "build",
            ")",
            "-prune",
            "-o",
            "-type",
            "f",
            "-print",
          })
        end

        require("telescope.builtin").find_files(options)
      end

      vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        once = true,
        callback = function()
          if #vim.api.nvim_list_uis() == 0 then
            return
          end

          local directories = allowed_directories()
          if #directories == 0 then
            vim.notify(
              "Aucun dossier autorisé. Configure TZF_SEARCH_DIRS dans ~/.config/fish/config.fish puis recharge Fish.",
              vim.log.levels.WARN
            )
            return
          end

          if vim.fn.argc() == 0 then
            local current_directory = vim.fs.normalize(vim.fn.getcwd())
            if not is_allowed(current_directory, directories) then
              vim.notify(
                "Dossier courant hors des racines autorisées : aucun sélecteur ouvert.",
                vim.log.levels.WARN
              )
              return
            end
            directories = { current_directory }
          end

          local directory_argument = false
          if vim.fn.argc() == 1 then
            local argument = vim.fn.argv(0)
            if vim.fn.isdirectory(argument) == 1 then
              local directory = vim.fs.normalize(vim.fn.fnamemodify(argument, ":p"))
              directory_argument = true
              if is_allowed(directory, directories) then
                directories = { directory }
                vim.api.nvim_set_current_dir(directory)
              else
                vim.notify(
                  "Dossier hors des racines autorisées : recherche limitée à NVIM_SEARCH_DIRS.",
                  vim.log.levels.WARN
                )
              end
            else
              return
            end
          elseif vim.fn.argc() > 1 then
            return
          end

          if directory_argument then
            local directory_buffer = vim.api.nvim_get_current_buf()
            vim.cmd.enew()
            pcall(vim.api.nvim_buf_delete, directory_buffer, { force = true })
          end

          vim.schedule(function()
            open_allowed_files(directories)
          end)
        end,
        desc = "Open the fuzzy file picker when Neovim starts without a file",
      })
    end,
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

      if vim.fn.executable("lazygit") == 1 then
        pcall(telescope.load_extension, "lazygit")
      end
      pcall(telescope.load_extension, "noice")
    end,
  },
  {
    "nvim-telescope/telescope-dap.nvim",
    dependencies = { "mfussenegger/nvim-dap", "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>df", "<Cmd>Telescope dap frames<CR>", desc = "DAP frames" },
      { "<leader>dl", "<Cmd>Telescope dap list_breakpoints<CR>", desc = "DAP breakpoints" },
    },
    config = function()
      require("telescope").load_extension("dap")
    end,
  },

  { "lewis6991/gitsigns.nvim", event = { "BufReadPre", "BufNewFile" }, opts = {} },
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerRun",
      "OverseerOpen",
      "OverseerClose",
      "OverseerToggle",
      "OverseerShell",
      "OverseerTaskAction",
    },
    opts = {
      task_list = {
        direction = "bottom",
        min_height = 10,
        max_height = 20,
      },
    },
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "williamboman/mason.nvim" },
      },
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
    },
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
    keys = {
      {
        "<F5>",
        function()
          require("dap").continue()
        end,
        desc = "DAP continue",
      },
      {
        "<F9>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "DAP toggle breakpoint",
      },
      {
        "<F10>",
        function()
          require("dap").step_over()
        end,
        desc = "DAP step over",
      },
      {
        "<F11>",
        function()
          require("dap").step_into()
        end,
        desc = "DAP step into",
      },
      {
        "<F12>",
        function()
          require("dap").step_out()
        end,
        desc = "DAP step out",
      },
      {
        "<leader>da",
        function()
          local dap = require("dap")
          for _, config in ipairs(dap.configurations[vim.bo.filetype] or {}) do
            if config.request == "attach" then
              dap.run(config)
              return
            end
          end
          vim.notify("Aucune configuration DAP attach pour ce langage", vim.log.levels.WARN)
        end,
        desc = "DAP attach",
      },
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "DAP toggle breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "DAP continue",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "DAP REPL",
      },
      {
        "<leader>dt",
        function()
          require("dap").terminate()
        end,
        desc = "DAP terminate",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "DAP UI",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      require("mason-nvim-dap").setup({
        ensure_installed = { "codelldb" },
        automatic_installation = false,
        handlers = {
          function(config)
            require("mason-nvim-dap").default_setup(config)
          end,
        },
      })

      local attach = {
        type = "codelldb",
        request = "attach",
        name = "LLDB: Attach to process",
        pid = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
      }
      for _, filetype in ipairs({ "c", "cpp" }) do
        dap.configurations[filetype] = dap.configurations[filetype] or {}
        local has_attach = vim.iter(dap.configurations[filetype]):any(function(config)
          return config.type == "codelldb" and config.request == "attach"
        end)
        if not has_attach then
          table.insert(dap.configurations[filetype], attach)
        end
      end

      dapui.setup()
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
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
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
}, {
  change_detection = {
    notify = false,
  },
})
