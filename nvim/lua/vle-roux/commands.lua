-- C goes through c_tools (CMake, Make, or every .c of the directory). A
-- lone C++ file is compiled next to itself; Python runs from :Run.
local c_tools = require("vle-roux.c_tools")
c_tools.setup()

local function run_terminal(command)
  require("vle-roux.terminal").open(command, 20)
end

local function single_cpp_build(opts)
  opts = opts or {}
  if vim.fn.executable("g++") ~= 1 then
    vim.notify("Commande indisponible : g++", vim.log.levels.WARN)
    return
  end

  vim.cmd("silent update")
  local command = { "g++", "-std=c++20", "-Wall", "-Wextra" }
  vim.list_extend(command, opts.debug and { "-g3", "-O0" } or { "-O2" })
  vim.list_extend(command, { "-o", vim.fn.expand("%:p:r"), vim.fn.expand("%:p") })
  c_tools.start_task(opts.debug and "G++ debug build" or "G++ build", command, vim.fn.expand("%:p:h"), opts.on_success)
end

local function single_cpp_run()
  local program = vim.fn.expand("%:p:r")
  if vim.fn.executable(program) ~= 1 then
    vim.notify("Exécutable absent. Lance :Build avant :Run.", vim.log.levels.WARN)
    return
  end
  run_terminal({ program })
end

vim.api.nvim_create_user_command("Build", function()
  local filetype = vim.bo.filetype
  if (filetype == "c" or filetype == "cpp") and c_tools.build() then
    return
  end
  if filetype == "cpp" then
    single_cpp_build()
  end
end, {})

vim.api.nvim_create_user_command("DebugBuild", function()
  local filetype = vim.bo.filetype

  -- A lone C file is rebuilt with -g3 -O0; projects own their debug mode.
  if filetype == "c" and c_tools.fallback_executable() then
    c_tools.build({ debug = true })
    return
  end

  if (filetype == "c" or filetype == "cpp") and c_tools.build() then
    vim.notify("Le mode Debug doit être défini par CMake/Make pour un projet.", vim.log.levels.INFO)
    return
  end

  if filetype == "cpp" then
    single_cpp_build({ debug = true })
  end
end, {})

vim.api.nvim_create_user_command("Run", function()
  local filetype = vim.bo.filetype

  local fallback_executable = c_tools.fallback_executable()
  if fallback_executable then
    if vim.fn.executable(fallback_executable) ~= 1 then
      vim.notify("Exécutable absent. Lance :Build avant :Run.", vim.log.levels.WARN)
      return
    end
    run_terminal({ fallback_executable })
    return
  end

  if (filetype == "c" or filetype == "cpp") and c_tools.project_root() then
    c_tools.open_task_picker()
    return
  end

  -- Python runs with the project's virtual environment when there is one.
  if filetype == "python" then
    local python = require("vle-roux.python").interpreter()
    if not python then
      vim.notify("Commande indisponible : python3", vim.log.levels.WARN)
      return
    end
    vim.cmd("silent update")
    run_terminal({ python, vim.fn.expand("%:p") })
    return
  end

  if filetype == "cpp" then
    single_cpp_run()
  end
end, {})

-- Build then run; the build is asynchronous, so :Run waits for success.
vim.api.nvim_create_user_command("Ha", function()
  local filetype = vim.bo.filetype
  if c_tools.is_c_family() and c_tools.project_root() then
    c_tools.build()
    vim.notify("Build lancé. Utilise :OverseerRun ou DAP pour exécuter la cible.", vim.log.levels.INFO)
    return
  end

  local function run()
    vim.cmd([[Run]])
  end

  if filetype == "c" and c_tools.fallback_executable() then
    c_tools.build({ on_success = run })
  elseif filetype == "cpp" then
    single_cpp_build({ on_success = run })
  else
    run()
  end
end, {})

vim.api.nvim_create_user_command("Config", function() vim.cmd.cd(vim.fn.stdpath("config")) end, {})

-- Plugins (lazy-lock.json is rewritten), Mason tools, Treesitter parsers.
vim.api.nvim_create_user_command("UpdateAll", function()
  for _, command in ipairs({ "Lazy sync", "MasonUpdate", "TSUpdate" }) do
    if vim.fn.exists(":" .. vim.split(command, " ")[1]) == 2 then
      vim.cmd(command)
    end
  end
end, { desc = "Mettre à jour plugins, outils Mason et parseurs Treesitter" })

vim.api.nvim_create_user_command("Norm42", function()
  require("vle-roux.norm42").toggle()
end, { desc = "Basculer la norme 42 (formatage et norminette) pour ce buffer" })

vim.api.nvim_create_user_command("Norm42Project", function(opts)
  require("vle-roux.norm42").set_project(opts.args)
end, {
  nargs = 1,
  complete = function()
    return { "on", "off", "clear" }
  end,
  desc = "Forcer (on), désactiver (off) ou oublier (clear) la norme 42 pour le projet",
})

vim.api.nvim_create_user_command("FormatOnSave", function()
  vim.g.format_on_save = not vim.g.format_on_save
  vim.notify("Formatage à la sauvegarde " .. (vim.g.format_on_save and "activé" or "désactivé"))
end, { desc = "Basculer le formatage automatique à la sauvegarde" })

vim.api.nvim_create_user_command("Norm42Adapt", function()
  require("vle-roux.norm42").toggle_adapt()
end, { desc = "Basculer colorcolumn et options de compilation liées à la norme 42" })

-- BufWritePost catches a header added with :Stdheader.
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "BufWritePost" }, {
  group = vim.api.nvim_create_augroup("vle_norm42", { clear = true }),
  callback = function()
    require("vle-roux.norm42").refresh_window()
  end,
  desc = "colorcolumn à 81 pour les fichiers à la norme 42",
})

local group = vim.api.nvim_create_augroup("vle_commands", { clear = true })

-- Web files conventionally use two spaces; .editorconfig still wins.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = {
    "html",
    "css",
    "scss",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
    "yaml",
  },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
  desc = "Two-space indentation for web files",
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "gitcommit", "text" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { "fr", "en" }
  end,
  desc = "Spell checking for prose",
})

vim.g.vle_word_count_enabled = false

vim.api.nvim_create_user_command("WordCount", function()
  vim.g.vle_word_count_enabled = not vim.g.vle_word_count_enabled
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh()
  end
end, {})

vim.api.nvim_create_user_command("MarkdownPreview", function()
  require("vle-roux.markdown_preview").toggle()
end, {})

vim.api.nvim_create_user_command("MarkdownPreviewRefresh", function()
  require("vle-roux.markdown_preview").refresh()
end, {})

vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = { "*.md", "*.markdown" },
  callback = function(args)
    require("vle-roux.markdown_preview").refresh_if_visible(args.buf)
  end,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
  group = group,
  pattern = { "*.md", "*.markdown" },
  callback = function(args)
    require("vle-roux.markdown_preview").sync_if_visible(args.buf)
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    require("vle-roux.markdown_preview").refresh_visible()
  end,
})
