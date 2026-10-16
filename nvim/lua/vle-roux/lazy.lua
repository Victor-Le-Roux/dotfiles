local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Impossible de cloner lazy.nvim :\n", "ErrorMsg" },
      { output, "WarningMsg" },
    }, true, {})
    return
  end
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
    -- Loaded at startup so Mason's bin directory (tree-sitter, prettierd...)
    -- is on PATH before other plugins look for those tools.
    "williamboman/mason.nvim",
    lazy = false,
    priority = 900,
    opts = {},
    config = function(_, opts)
      require("mason").setup(opts)
      require("vle-roux.tools").ensure_installed()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "williamboman/mason.nvim" },
      { "williamboman/mason-lspconfig.nvim" },
      { "saghen/blink.cmp" },
    },
    config = function()
      local Remap = require("vle-roux.keymap")
      local inoremap = Remap.inoremap
      local nnoremap = Remap.nnoremap
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local mason_lspconfig = require("mason-lspconfig")

      local severity = vim.diagnostic.severity
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = { spacing = 2, source = "if_many", prefix = "●" },
        float = { border = "rounded", source = "if_many" },
        signs = {
          text = {
            [severity.ERROR] = "E",
            [severity.WARN] = "W",
            [severity.INFO] = "I",
            [severity.HINT] = "H",
          },
        },
        jump = {
          on_jump = function(diagnostic, bufnr)
            if diagnostic then
              vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
            end
          end,
        },
      })

      local function on_attach(client, bufnr)
        local function opts(desc)
          return { buffer = bufnr, silent = true, desc = desc }
        end

        -- basedpyright provides hover for Python; ruff only lints and formats.
        if client.name == "ruff" then
          client.server_capabilities.hoverProvider = false
        end

        nnoremap("<leader>.", vim.lsp.buf.code_action, opts("Code action"))
        nnoremap("<leader>rn", vim.lsp.buf.rename, opts("Rename symbol"))
        nnoremap("<leader>fi", vim.lsp.buf.implementation, opts("Go to implementation"))
        nnoremap("<leader>fr", vim.lsp.buf.references, opts("References"))
        nnoremap("<leader>ff", vim.lsp.buf.definition, opts("Go to definition"))
        nnoremap("<leader>fF", vim.lsp.buf.declaration, opts("Go to declaration"))
        nnoremap("<leader>fs", "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>", opts("Workspace symbols"))
        nnoremap("<leader>fd", "<Cmd>Telescope diagnostics bufnr=0<CR>", opts("Buffer diagnostics"))
        nnoremap("<leader>fh", function()
          switch_source_header(bufnr)
        end, opts("Switch source / header"))
        nnoremap("<leader>fci", vim.lsp.buf.incoming_calls, opts("Incoming calls"))
        nnoremap("<leader>fco", vim.lsp.buf.outgoing_calls, opts("Outgoing calls"))
        inoremap("<C-j>", vim.lsp.buf.signature_help, opts("Signature help"))
        nnoremap("<leader>vi", function()
          local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
          vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
        end, opts("Toggle inlay hints"))
      end

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
          -- Never add #include lines on completion (42 norm, explicit headers).
          "--header-insertion=never",
          "--function-arg-placeholders",
          "--pch-storage=memory",
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
        before_init = function(init_params, config)
          local options = require("vle-roux.c_tools").clangd_init_options(config.root_dir)
          if next(options) then
            init_params.initializationOptions =
              vim.tbl_deep_extend("force", init_params.initializationOptions or {}, options)
          end
        end,
      })

      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            -- ruff organizes imports; "standard" avoids basedpyright's very
            -- strict default checks.
            disableOrganizeImports = true,
            analysis = { typeCheckingMode = "standard" },
          },
        },
        -- Mutate the settings table in place: the client keeps a reference
        -- to it and answers the server's configuration requests from it.
        before_init = function(_, config)
          local python = require("vle-roux.python").venv_python(config.root_dir)
          if python then
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = python
          end
        end,
      })

      mason_lspconfig.setup({
        ensure_installed = {},
        automatic_enable = false,
      })

      local enabled_servers = {}
      for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        enabled_servers[server_name] = true
      end
      -- clangd comes from the system, not from Mason.
      if vim.fn.executable("clangd") == 1 then
        enabled_servers.clangd = true
      end
      for server_name in pairs(enabled_servers) do
        vim.lsp.enable(server_name)
      end
    end,
  },

  {
    -- Formatting: c_formatter_42 for norm files, clang-format, ruff, stylua
    -- and prettierd otherwise, the LSP when none of them is available.
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>m",
        function()
          require("conform").format({ async = false, timeout_ms = 10000, lsp_format = "fallback" })
        end,
        desc = "Format buffer",
      },
    },
    opts = function()
      local prettier = { "prettierd" }
      return {
        formatters_by_ft = {
          c = function(bufnr)
            if require("vle-roux.norm42").enabled(bufnr) then
              -- Never fall back to clangd: its style would break the norm.
              return { "c_formatter_42", lsp_format = "never" }
            end
            return { "clang-format" }
          end,
          cpp = { "clang-format" },
          python = { "ruff_format" },
          lua = { "stylua" },
          javascript = prettier,
          javascriptreact = prettier,
          typescript = prettier,
          typescriptreact = prettier,
          json = prettier,
          jsonc = prettier,
          css = prettier,
          scss = prettier,
          html = prettier,
          markdown = prettier,
          yaml = prettier,
        },
        formatters = {
          c_formatter_42 = { command = "c_formatter_42", stdin = true },
        },
        -- Off by default; :FormatOnSave toggles it.
        format_on_save = function()
          if vim.g.format_on_save then
            return { timeout_ms = 3000, lsp_format = "fallback" }
          end
        end,
      }
    end,
  },
  {
    -- norminette diagnostics on files following the 42 norm.
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local norm42 = require("vle-roux.norm42")
      require("lint").linters.norminette = norm42.linter()

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("vle_lint", { clear = true }),
        callback = function(args)
          norm42.lint(args.buf)
        end,
        desc = "Run norminette on norm files",
      })
    end,
  },
  {
    -- Neovim API types for lua_ls while editing this configuration.
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
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
        menu = { border = "rounded", max_height = 8 },
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
        per_filetype = {
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
  { "tikhomirov/vim-glsl", ft = { "glsl", "vert", "frag", "tesc", "tese", "geom", "comp" } },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle", "NvimTreeCollapse" },
    keys = {
      { "<leader><tab>", "<Cmd>NvimTreeToggle<CR>", desc = "File tree" },
      { "<leader>f<tab>", "<Cmd>NvimTreeFindFile!<CR>", desc = "Reveal file in tree" },
      { "<leader>z", "<Cmd>NvimTreeCollapse<CR>", desc = "Collapse file tree" },
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
            -- A function so the float follows the current editor size.
            open_win_config = function()
              return {
                relative = "editor",
                border = "rounded",
                width = math.floor(vim.o.columns * 0.8),
                height = vim.o.lines - 6,
                row = 2,
                col = math.floor(vim.o.columns * 0.1),
              }
            end,
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

      local function absolute(path)
        return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
      end

      local function sync(evt, list)
        local file = absolute(evt.file)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row, col = cursor[1], cursor[2]

        for _, item in pairs(list.items) do
          if absolute(item.value) == file then
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
      -- Code actions and other vim.ui.select menus use Telescope: the first
      -- call loads it, and the ui-select extension then replaces this stub.
      local builtin_select = vim.ui.select
      vim.ui.select = function(...)
        -- Restored first: if Telescope fails to load, the built-in menu is
        -- used instead of calling this stub forever.
        vim.ui.select = builtin_select
        require("lazy").load({ plugins = { "telescope.nvim" } })
        return vim.ui.select(...)
      end

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

          -- The picker only opens without arguments or with a single directory.
          local argc = vim.fn.argc()
          if argc > 1 or (argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 0) then
            return
          end

          local directories = allowed_directories()
          if #directories == 0 then
            vim.notify(
              "Aucun dossier autorisé. Configure NVIM_SEARCH_DIRS dans ~/.config/fish/config.fish puis recharge Fish.",
              vim.log.levels.WARN
            )
            return
          end

          if argc == 0 then
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

          local directory_argument = argc == 1
          if directory_argument then
            local directory = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.argv(0), ":p"))
            if is_allowed(directory, directories) then
              directories = { directory }
              vim.api.nvim_set_current_dir(directory)
            else
              vim.notify(
                "Dossier hors des racines autorisées : recherche limitée à NVIM_SEARCH_DIRS.",
                vim.log.levels.WARN
              )
            end
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
        desc = "Find files",
      },
      {
        "<leader>x",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Live grep",
      },
      {
        "<leader>b",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Buffers",
      },
    },
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "kdheepak/lazygit.nvim" },
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      { "nvim-telescope/telescope-ui-select.nvim" },
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
            "^target/",
            "/target/",
            "^build/",
            "/build/",
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
          fzf = { case_mode = "smart_case" },
          ["ui-select"] = { require("telescope.themes").get_dropdown() },
        },
      })

      pcall(telescope.load_extension, "fzf")
      telescope.load_extension("ui-select")
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
    config = function(_, opts)
      require("overseer").setup(opts)
      require("vle-roux.c_tools").register_templates()
    end,
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
      { "theHamsta/nvim-dap-virtual-text" },
      { "mfussenegger/nvim-dap-python" },
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

      local c_tools = require("vle-roux.c_tools")

      require("mason-nvim-dap").setup({
        -- codelldb is installed by tools.lua.
        ensure_installed = {},
        automatic_installation = false,
        handlers = {
          function(config)
            require("mason-nvim-dap").default_setup(config)
          end,
          -- Only the adapter: the launch configurations below remember the
          -- program instead of asking for it every time.
          codelldb = function(config)
            config.configurations = {}
            require("mason-nvim-dap").default_setup(config)
          end,
          -- Python is configured by nvim-dap-python below.
          python = function() end,
        },
      })

      -- gdb >= 14 speaks DAP natively: often more reliable than lldb for C.
      if vim.fn.executable("gdb") == 1 then
        dap.adapters.gdb = {
          type = "executable",
          command = "gdb",
          args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
        }
      end

      -- Paths in the debugged program are relative to the project root,
      -- not to the directory Neovim was started from.
      local function project_cwd()
        return c_tools.project_root() or vim.uv.cwd()
      end

      -- The program and its arguments are asked once, then remembered.
      local c_configurations = {
        {
          type = "codelldb",
          request = "launch",
          name = "LLDB : lancer le programme",
          program = c_tools.dap_program,
          args = c_tools.dap_args,
          cwd = project_cwd,
          stopOnEntry = false,
          -- Runs in a terminal (dap-ui console) so the program can read stdin.
          terminal = "integrated",
        },
        {
          type = "codelldb",
          request = "attach",
          name = "LLDB: Attach to process",
          pid = require("dap.utils").pick_process,
          cwd = project_cwd,
        },
      }
      if dap.adapters.gdb then
        table.insert(c_configurations, {
          type = "gdb",
          request = "launch",
          name = "GDB : lancer le programme",
          program = c_tools.dap_program,
          args = c_tools.dap_args,
          cwd = project_cwd,
          stopAtBeginningOfMainSubprogram = false,
        })
      end

      for _, filetype in ipairs({ "c", "cpp" }) do
        dap.configurations[filetype] = dap.configurations[filetype] or {}
        for _, configuration in ipairs(c_configurations) do
          local exists = vim.iter(dap.configurations[filetype]):any(function(config)
            return config.name == configuration.name
          end)
          if not exists then
            table.insert(dap.configurations[filetype], configuration)
          end
        end
      end

      -- debugpy runs from Mason's venv; the debugged program uses the
      -- project's virtual environment.
      local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      local dap_python = require("dap-python")
      dap_python.setup(vim.fn.executable(debugpy) == 1 and debugpy or "python3")
      dap_python.test_runner = "pytest"
      dap_python.resolve_python = function()
        return require("vle-roux.python").interpreter()
      end

      require("nvim-dap-virtual-text").setup({})
      dapui.setup()
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      -- The UI stays open when the program ends, so the output and the last
      -- stack remain readable after a crash. Close it with <leader>du.
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
        -- blink.cmp shows signature help and follows window resizes.
        signature = { enabled = false },
      },
      presets = {
        long_message_to_split = false,
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
    "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp" },
    keys = {
      { "<leader>ca", "<Cmd>ClangdAST<CR>", desc = "clangd: AST of the current node", ft = { "c", "cpp" } },
      { "<leader>ci", "<Cmd>ClangdSymbolInfo<CR>", desc = "clangd: symbol info", ft = { "c", "cpp" } },
      { "<leader>cH", "<Cmd>ClangdTypeHierarchy<CR>", desc = "clangd: type hierarchy", ft = { "c", "cpp" } },
    },
    opts = {},
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "alfaix/neotest-gtest",
    },
    keys = {
      {
        "<leader>nr",
        function()
          require("neotest").run.run()
        end,
        desc = "Run nearest test",
      },
      {
        "<leader>nf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run tests in file",
      },
      {
        "<leader>nd",
        function()
          require("neotest").run.run({ strategy = "dap" })
        end,
        desc = "Debug nearest test",
      },
      {
        "<leader>nl",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Re-run last test",
      },
      {
        "<leader>nx",
        function()
          require("neotest").run.stop()
        end,
        desc = "Stop tests",
      },
      {
        "<leader>ns",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Test summary",
      },
      {
        "<leader>no",
        function()
          require("neotest").output.open({ enter = true, auto_close = true })
        end,
        desc = "Test output",
      },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            runner = "pytest",
            python = function()
              return require("vle-roux.python").interpreter()
            end,
            dap = { justMyCode = false },
          }),
          require("neotest-gtest").setup({}),
        },
      })
    end,
  },
  {
    -- Python REPL (IPython when the environment has it) fed from the buffer.
    "Vigemus/iron.nvim",
    ft = "python",
    cmd = { "IronRepl", "IronRestart", "IronFocus", "IronHide" },
    config = function()
      require("iron.core").setup({
        config = {
          scratch_repl = true,
          repl_open_cmd = require("iron.view").split.vertical.botright("40%"),
          repl_definition = {
            python = {
              command = function(meta)
                return require("vle-roux.python").repl_command(meta.current_bufnr)
              end,
              format = require("iron.fts.common").bracketed_paste_python,
              block_dividers = { "# %%", "#%%" },
            },
          },
        },
        keymaps = {
          toggle_repl = "<leader>ir",
          restart_repl = "<leader>iR",
          send_motion = "<leader>is",
          visual_send = "<leader>is",
          send_line = "<leader>il",
          send_paragraph = "<leader>ip",
          send_code_block = "<leader>ib",
          send_file = "<leader>if",
          interrupt = "<leader>ic",
          clear = "<leader>ix",
          exit = "<leader>iq",
        },
      })
    end,
  },
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
}, {
  change_detection = {
    notify = false,
  },
})
