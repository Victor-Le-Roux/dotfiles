-- Language servers, Mason and Lua API types.

return {
  {
    -- Loaded at startup so Mason's bin directory (tree-sitter, prettierd...)
    -- is on PATH before other plugins look for those tools.
    "mason-org/mason.nvim",
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
      { "mason-org/mason.nvim" },
      { "mason-org/mason-lspconfig.nvim" },
      { "saghen/blink.cmp" },
    },
    config = function()
      local Remap = require("vle-roux.keymap")
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

      -- An LspAttach autocmd rather than on_attach in vim.lsp.config("*"):
      -- nvim-lspconfig gives clangd, basedpyright and ts_ls their own
      -- on_attach, which would replace a shared one.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("vle_lsp", { clear = true }),
        callback = function(args)
          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end
          local function opts(desc)
            return { buffer = bufnr, silent = true, desc = desc }
          end

          -- basedpyright provides hover for Python; ruff only lints and formats.
          if client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end

          -- The command comes from nvim-lspconfig's clangd on_attach.
          if client.name == "clangd" then
            nnoremap("<leader>fh", "<Cmd>LspClangdSwitchSourceHeader<CR>", opts("Switch source / header"))
          end

          nnoremap("<leader>.", vim.lsp.buf.code_action, opts("Code action"))
          nnoremap("<leader>rn", vim.lsp.buf.rename, opts("Rename symbol"))
          nnoremap("<leader>fi", vim.lsp.buf.implementation, opts("Go to implementation"))
          nnoremap("<leader>fr", vim.lsp.buf.references, opts("References"))
          nnoremap("<leader>ff", vim.lsp.buf.definition, opts("Go to definition"))
          nnoremap("<leader>fF", vim.lsp.buf.declaration, opts("Go to declaration"))
          nnoremap("<leader>fs", "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>", opts("Workspace symbols"))
          nnoremap("<leader>fd", "<Cmd>Telescope diagnostics bufnr=0<CR>", opts("Buffer diagnostics"))
          nnoremap("<leader>fci", vim.lsp.buf.incoming_calls, opts("Incoming calls"))
          nnoremap("<leader>fco", vim.lsp.buf.outgoing_calls, opts("Outgoing calls"))
          nnoremap("<leader>vi", function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
          end, opts("Toggle inlay hints"))
        end,
        desc = "LSP keymaps",
      })

      vim.lsp.config("*", {
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
      -- Servers may also come from the system (clangd) or from pip
      -- (basedpyright where Mason cannot build Python environments).
      for _, server_name in ipairs({ "clangd", "basedpyright", "ruff", "lua_ls" }) do
        local cmd = vim.lsp.config[server_name] and vim.lsp.config[server_name].cmd
        if type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1 then
          enabled_servers[server_name] = true
        end
      end
      for server_name in pairs(enabled_servers) do
        vim.lsp.enable(server_name)
      end
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
    "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp" },
    keys = {
      { "<leader>ca", "<Cmd>ClangdAST<CR>", desc = "clangd: AST of the current node", ft = { "c", "cpp" } },
      { "<leader>ci", "<Cmd>ClangdSymbolInfo<CR>", desc = "clangd: symbol info", ft = { "c", "cpp" } },
      { "<leader>cH", "<Cmd>ClangdTypeHierarchy<CR>", desc = "clangd: type hierarchy", ft = { "c", "cpp" } },
    },
    opts = {},
  },
}
