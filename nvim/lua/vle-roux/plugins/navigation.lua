-- File navigation: Telescope (and the startup picker), nvim-tree, Harpoon.

-- live_grep needs ripgrep. Without it (42 workstations), grep -R fills the
-- quickfix list instead.
local function grep_to_quickfix()
  vim.ui.input({ prompt = "grep : " }, function(query)
    if not query or query == "" then
      return
    end
    local command = { "grep", "-RIn", "--exclude-dir=.git", "--exclude-dir=node_modules", "--exclude-dir=build" }
    vim.list_extend(command, { "-e", query, "." })
    local result = vim.system(command, { text = true }):wait()
    if result.code > 1 then
      vim.notify("grep a échoué : " .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end
    local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
    vim.fn.setqflist({}, " ", { title = "grep " .. query, lines = lines, efm = "%f:%l:%m" })
    if #lines == 0 then
      vim.notify("Aucun résultat pour " .. query)
      return
    end
    vim.cmd("botright copen")
  end)
end

-- <leader>a add, <leader>e menu, <leader>1..9/0 files 1..10, <leader>hn/hp.
local function harpoon_keys()
  local function list()
    return require("harpoon"):list()
  end

  local keys = {
    {
      "<leader>a",
      function()
        list():add()
      end,
      desc = "Harpoon add file",
    },
    {
      "<leader>e",
      function()
        require("harpoon").ui:toggle_quick_menu(list())
      end,
      desc = "Harpoon menu",
    },
    {
      "<leader>hn",
      function()
        list():next()
      end,
      desc = "Harpoon next file",
    },
    {
      "<leader>hp",
      function()
        list():prev()
      end,
      desc = "Harpoon previous file",
    },
  }
  for index = 1, 10 do
    keys[#keys + 1] = {
      "<leader>" .. (index % 10),
      function()
        list():select(index)
      end,
      desc = "Harpoon file " .. index,
    }
  end
  return keys
end

return {
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
        renderer = vim.g.have_nerd_font and {} or {
          icons = {
            show = { file = false, folder = false },
            glyphs = {
              folder = { arrow_closed = ">", arrow_open = "v" },
              git = {
                unstaged = "M",
                staged = "S",
                unmerged = "U",
                renamed = "R",
                untracked = "?",
                deleted = "D",
                ignored = "!",
              },
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
    keys = harpoon_keys(),
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
          if vim.fn.executable("rg") == 1 then
            require("telescope.builtin").live_grep()
          else
            grep_to_quickfix()
          end
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
          find_files = { hidden = true, disable_devicons = not vim.g.have_nerd_font },
          live_grep = { only_sort_text = true, disable_devicons = not vim.g.have_nerd_font },
          buffers = { disable_devicons = not vim.g.have_nerd_font },
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
}
