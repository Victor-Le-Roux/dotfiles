-- Formatting (conform) and norminette diagnostics (nvim-lint).

return {
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
          -- flake8's line length where flake8 lints (42 projects).
          ruff_format = {
            args = function(_, ctx)
              local args = { "format", "--force-exclude" }
              local length = require("vle-roux.python").format_line_length(ctx.buf)
              if length then
                vim.list_extend(args, { "--line-length", tostring(length) })
              end
              return vim.list_extend(args, { "--stdin-filename", "$FILENAME", "-" })
            end,
          },
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
    -- norminette diagnostics on files following the 42 norm, flake8 and
    -- mypy on Python files (see python.lua).
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local norm42 = require("vle-roux.norm42")
      local python = require("vle-roux.python")
      require("lint").linters.norminette = norm42.linter()

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = vim.api.nvim_create_augroup("vle_lint", { clear = true }),
        callback = function(args)
          norm42.lint(args.buf)
          python.lint(args.buf)
        end,
        desc = "Run norminette, flake8 and mypy",
      })

      -- The plugin loads during the first BufReadPost, before the autocmd
      -- above exists: lint the buffers already open once filetypes are set.
      vim.schedule(function()
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            norm42.lint(bufnr)
            python.lint(bufnr)
          end
        end
      end)
    end,
  },
}
