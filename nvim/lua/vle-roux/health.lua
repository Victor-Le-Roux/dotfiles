-- :checkhealth vle-roux: external tools this configuration relies on.
local M = {}

local health = vim.health

-- `purpose` says what is lost without the tool.
local function check_executable(name, purpose, advice)
  local path = vim.fn.exepath(name)
  if path ~= "" then
    health.ok(name .. " : " .. path)
  else
    health.warn(name .. " introuvable : " .. purpose, advice)
  end
end

local function first_c_buffer(c_tools)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and c_tools.is_c_family(bufnr) then
      return bufnr
    end
  end
end

local function check_c()
  local c_tools = require("vle-roux.c_tools")
  health.start("vle-roux : C / C++")

  local clangd = c_tools.clangd_command()
  if vim.fn.executable(clangd) == 1 then
    health.ok("clangd : " .. clangd)
  else
    health.error("clangd introuvable : pas de LSP pour C/C++", "pacman -S clang")
  end

  check_executable("codelldb", "débogage LLDB", ":MasonInstall codelldb")
  check_executable("gdb", "adaptateur DAP gdb")
  check_executable("cmake", ":CConfigure, :Build et :CTest des projets CMake")
  check_executable("ninja", ":CConfigure utilise le générateur par défaut")
  check_executable("make", ":Build des projets Makefile")
  if vim.fn.executable("bear") == 1 then
    health.ok("bear : " .. vim.fn.exepath("bear"))
  else
    check_executable("compiledb", ":CBear (compile_commands.json des Makefile)", "bear ou pip install compiledb")
  end
  check_executable("valgrind", "tâche Overseer valgrind")

  local bufnr = first_c_buffer(c_tools)
  if not bufnr then
    health.info("Aucun buffer C ouvert : racine et base de compilation non vérifiées")
    return
  end

  local data = c_tools.health_data(bufnr)
  health.info("Buffer : " .. vim.api.nvim_buf_get_name(bufnr))
  health.info("Racine : " .. data.root)
  if data.compilation_database == "absente" then
    health.warn("Base de compilation absente : clangd devine les options", {
      "Makefile : :CBear",
      "CMake : :CConfigure",
    })
  else
    health.ok("Base de compilation : " .. data.compilation_database)
  end
  if data.clangd_attached then
    health.ok("clangd attaché (racine " .. data.clangd_root .. ")")
  else
    health.warn("clangd n'est pas attaché à ce buffer")
  end
end

local function check_norm42()
  health.start("vle-roux : norme 42")
  check_executable("norminette", "pas de diagnostics de norme", "pipx install norminette")
  check_executable("c_formatter_42", "pas de formatage à la norme", "pipx install c-formatter-42")
end

local function check_python()
  health.start("vle-roux : Python")
  local python = require("vle-roux.python").interpreter()
  if python then
    health.ok("Interpréteur : " .. python)
  else
    health.warn("python3 introuvable : :Run, REPL et debugpy indisponibles")
  end
end

local function check_misc()
  health.start("vle-roux : divers")
  -- "+y needs a clipboard tool; xclip, xsel or wl-copy cannot be
  -- installed without root, but the terminal's own copy still works.
  if vim.fn.has("clipboard") == 1 then
    health.ok("Presse-papiers système disponible (<leader>y)")
  else
    health.warn("Aucun presse-papiers système (xclip, xsel, wl-copy) : <leader>y ne copie pas hors de Neovim", {
      "Sélectionne le texte à la souris dans le terminal, ou utilise Ctrl+Shift+C",
    })
  end
  check_executable("rg", "Telescope live_grep", "pacman -S ripgrep")
  check_executable("glow", "aperçu Markdown (<leader>vm)", "pacman -S glow")
  check_executable("lazygit", "extension Telescope lazygit")
  -- fish is optional: terminals fall back to $SHELL (zsh at 42).
  if vim.fn.executable("fish") ~= 1 then
    health.info("fish absent : les terminaux ouvrent " .. (vim.env.SHELL or vim.o.shell) .. ", <leader>cr lance :Ha")
  else
    local ok, result = pcall(function()
      return vim.system({ "fish", "-c", "functions -q crun" }):wait(2000)
    end)
    if ok and result.code == 0 then
      health.ok("Fonction fish crun disponible (<leader>cr)")
    else
      health.warn("Fonction fish crun introuvable : <leader>cr échouera")
    end
  end

  local directories = vim.split(vim.env.NVIM_SEARCH_DIRS or "", ":", { plain = true, trimempty = true })
  if #directories == 0 then
    health.warn("NVIM_SEARCH_DIRS vide : pas de sélecteur de fichiers au démarrage", {
      "Le définir dans ~/.config/fish/config.fish",
    })
  else
    for _, directory in ipairs(directories) do
      local path = vim.fn.expand(directory)
      if vim.fn.isdirectory(path) == 1 then
        health.ok("NVIM_SEARCH_DIRS : " .. path)
      else
        health.warn("NVIM_SEARCH_DIRS : " .. path .. " n'existe pas")
      end
    end
  end
end

local function check_mason()
  health.start("vle-roux : outils Mason")
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    health.warn("Mason n'est pas chargé")
    return
  end
  local refreshed = false
  registry.refresh(function()
    refreshed = true
  end)
  vim.wait(10000, function()
    return refreshed
  end, 100)

  local plan = require("vle-roux.tools").plan(registry)
  for _, skipped in ipairs(plan.skipped) do
    if skipped[2]:find("hors Mason", 1, true) then
      health.ok(skipped[1] .. " " .. skipped[2])
    else
      health.warn(skipped[1] .. " non installable : " .. skipped[2])
    end
  end
  for _, package in ipairs(plan.install) do
    health.info(package.name .. " sera installé au prochain démarrage")
  end
  if #plan.skipped == 0 and #plan.install == 0 then
    health.ok("Tous les outils Mason sont installés")
  end
end

function M.check()
  check_mason()
  check_c()
  check_norm42()
  check_python()
  check_misc()
end

return M
