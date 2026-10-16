-- Single-file builds. C files without a build system go through c_tools
-- (every .c of the directory); Python runs from :Run.
local build_commands = {
  c = "!gcc -std=c17 -Wall -Wextra -O2 -o %:p:r %",
  cpp = "!g++ -std=c++20 -Wall -Wextra -O2 -o %:p:r %",
}

local debug_build_commands = {
  c = "!gcc -std=c17 -Wall -Wextra -g3 -O0 -o %:p:r %",
  cpp = "!g++ -std=c++20 -Wall -Wextra -g3 -O0 -o %:p:r %",
}

local run_commands = {
  c = "%:p:r",
  cpp = "%:p:r",
}

local required_commands = {
  c = "gcc",
  cpp = "g++",
}

local c_tools = require("vle-roux.c_tools")
c_tools.setup()

local function has_required_command(filetype)
  local command = required_commands[filetype]
  if not command or vim.fn.executable(command) == 1 then
    return true
  end

  vim.notify("Commande indisponible : " .. command, vim.log.levels.WARN)
  return false
end

local function run_terminal(command)
  vim.cmd("sp")
  vim.cmd("terminal " .. command)
  vim.cmd("resize 20N")
  vim.cmd("startinsert")
end

vim.api.nvim_create_user_command("Build", function()
  local filetype = vim.bo.filetype

  if (filetype == "c" or filetype == "cpp") and c_tools.build() then
    return
  end

  if not has_required_command(filetype) then
    return
  end

  for file, command in pairs(build_commands) do
    if filetype == file then
      vim.cmd(command)
      break
    end
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

  if not has_required_command(filetype) then
    return
  end

  for file, command in pairs(debug_build_commands) do
    if filetype == file then
      vim.cmd(command)
      break
    end
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
    run_terminal(vim.fn.shellescape(fallback_executable))
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
    run_terminal(vim.fn.shellescape(python) .. " " .. vim.fn.shellescape(vim.fn.expand("%:p")))
    return
  end

  if not has_required_command(filetype) then
    return
  end

  for file, command in pairs(run_commands) do
    if filetype == file then
      run_terminal(command)
      break
    end
  end
end, {})

vim.api.nvim_create_user_command("Ha", function()
  if c_tools.is_c_family() and c_tools.project_root() then
    c_tools.build()
    vim.notify("Build lancé. Utilise :OverseerRun ou DAP pour exécuter la cible.", vim.log.levels.INFO)
    return
  end

  -- The C fallback build is asynchronous: run only once it has succeeded.
  if vim.bo.filetype == "c" and c_tools.fallback_executable() then
    c_tools.build({
      on_success = function()
        vim.cmd([[Run]])
      end,
    })
    return
  end

  vim.cmd([[Build]])
  vim.cmd([[Run]])
end, {})

vim.api.nvim_create_user_command("Config", function() vim.cmd.cd(vim.fn.stdpath("config")) end, {})

vim.api.nvim_create_user_command("UpdateAll", function()
  if vim.fn.exists(":MasonUpdate") == 2 then
    vim.cmd([[MasonUpdate]])
  end
end, {})

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

-- Web files conventionally use two spaces; .editorconfig still wins.
vim.api.nvim_create_autocmd("FileType", {
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
  pattern = { "*.md", "*.markdown" },
  callback = function(args)
    require("vle-roux.markdown_preview").refresh_if_visible(args.buf)
  end,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
  pattern = { "*.md", "*.markdown" },
  callback = function(args)
    require("vle-roux.markdown_preview").sync_if_visible(args.buf)
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    require("vle-roux.markdown_preview").refresh_visible()
  end,
})
