-- Tasks, debugging, tests and the Python REPL.

return {
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
        dependencies = { "mason-org/mason.nvim" },
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
      -- Ubuntu 22.04 ships gdb 12, which does not.
      local function gdb_speaks_dap()
        if vim.fn.executable("gdb") ~= 1 then
          return false
        end
        local ok, result = pcall(function()
          return vim.system({ "gdb", "--version" }, { text = true }):wait(3000)
        end)
        local major = ok and tonumber((result.stdout or ""):match("(%d+)%.%d+")) or 0
        return major >= 14
      end
      if gdb_speaks_dap() then
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
      -- codelldb is optional in the light profile (NVIM_PROFILE=light).
      local c_configurations = {}
      vim.list_extend(c_configurations, dap.adapters.codelldb == nil and {} or {
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
      })
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

      -- debugpy runs from Mason's venv, or from a pip install
      -- (debugpy-adapter) where Mason cannot build Python environments; the
      -- debugged program uses the project's virtual environment.
      local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      local debugpy_adapter = vim.fn.exepath("debugpy-adapter")
      local dap_python = require("dap-python")
      if vim.fn.executable(debugpy) == 1 then
        dap_python.setup(debugpy)
      elseif debugpy_adapter ~= "" then
        dap_python.setup(debugpy_adapter)
      else
        dap_python.setup("python3")
      end
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
}
