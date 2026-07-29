local build_commands = {
  c = "!gcc -std=c17 -Wall -Wextra -O2 -o %:p:r.o %",
  cpp = "!g++ -std=c++17 -Wall -O2 -o %:p:r.o %",
  rust = "!cargo build --release",
  go = "!go build",
  -- tex = "pdflatex %",
  tex = "VimtexCompile",
  javascript = "",
}

local debug_build_commands = {
  c = "!gcc -std=c17 -Wall -Wextra -g -O0 -o %:p:r.o %",
  cpp = "!g++ -std=c++17 -g -o %:p:r.o %",
  rust = "!cargo build",
  go = "!go build",
}

local run_commands = {
  c = "%:p:r.o",
  cpp = "%:p:r.o",
  rust = "cargo run --release",
  -- go = "%:p:r.o",
  go = "go run .",
  -- tex = "open %:p:r.pdf",
  tex = "",
  javascript = "node %",
}

local required_commands = {
  c = "gcc",
  cpp = "g++",
  rust = "cargo",
  go = "go",
  javascript = "node",
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

  vim.cmd([[Build]])
  vim.cmd([[Run]])
end, {})

vim.api.nvim_create_user_command("Config", function() vim.cmd([[cd ~/.config/nvim]]) end, {})

vim.api.nvim_create_user_command("UpdateAll", function()
  if vim.fn.exists(":TSUpdateSync") == 2 then
    vim.cmd([[TSUpdateSync]])
  end
  if vim.fn.exists(":MasonUpdate") == 2 then
    vim.cmd([[MasonUpdate]])
  end
end, {})

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

local function rot13_char(char)
  local byte = string.byte(char)
  if not byte then
    return char
  end

  if byte >= 65 and byte <= 90 then
    return string.char(((byte - 65 + 13) % 26) + 65)
  end

  if byte >= 97 and byte <= 122 then
    return string.char(((byte - 97 + 13) % 26) + 97)
  end

  return char
end

local rot13_enabled = false
local rot13_id = nil

vim.api.nvim_create_user_command("Rot13", function()
  if not rot13_enabled then
    rot13_id = vim.api.nvim_create_autocmd({ "InsertCharPre" }, {
      pattern = { "*" },
      callback = function()
        if vim.v.char and #vim.v.char == 1 then
          vim.v.char = rot13_char(vim.v.char)
        end
      end,
    })
    rot13_enabled = true
  else
    if rot13_id then
      pcall(vim.api.nvim_del_autocmd, rot13_id)
    end
    rot13_enabled = false
    rot13_id = nil
  end
end, {})

-- local writingModeOn = false

-- vim.api.nvim_create_user_command("WritingMode", function()
--   if writingModeOn then
--     vim.cmd([[set nowrap]])
--     nnoremap("j", "j")
--     nnoremap("k", "k")
--     writingModeOn = false
--   else
--     vim.cmd([[set wrap]])
--     nnoremap("j", "gj")
--     nnoremap("k", "gk")
--     writingModeOn = true
--   end
-- end, {})
