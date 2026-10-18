-- External tools installed through Mason, so a fresh machine gets them back.
-- A package is skipped when the tool already exists outside Mason (system
-- clangd, pip-installed basedpyright...) or when Mason cannot install it
-- here: npm packages need npm, pypi ones need `python3 -m venv` with
-- ensurepip (missing on Ubuntu without python3-venv, e.g. 42 workstations).
local M = {}

M.packages = {
  -- C / C++ (clang-format comes from the system when available)
  "clangd",
  "codelldb",
  "neocmakelsp",
  -- Lua (this configuration)
  "lua-language-server",
  "stylua",
  -- Python
  "basedpyright",
  "ruff",
  "debugpy",
  -- Web
  "typescript-language-server",
  "html-lsp",
  "css-lsp",
  "emmet-language-server",
  "prettierd",
  -- Treesitter parser builds
  "tree-sitter-cli",
}

-- Command that proves a package is already provided by something else.
local provided_by = {
  clangd = "clangd",
  basedpyright = "basedpyright-langserver",
  debugpy = "debugpy-adapter",
  ruff = "ruff",
  ["tree-sitter-cli"] = "tree-sitter",
}

local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

local function provided_outside_mason(name)
  local command = provided_by[name]
  local path = command and vim.fn.exepath(command) or ""
  return path ~= "" and not vim.startswith(path, mason_bin)
end

local python_venv_ok

local function python_can_create_venvs()
  if python_venv_ok == nil then
    local ok, result = pcall(function()
      return vim.system({ "python3", "-c", "import ensurepip, venv" }):wait(5000)
    end)
    python_venv_ok = ok and result.code == 0
  end
  return python_venv_ok
end

-- nil when Mason can install the package, otherwise the reason it cannot.
local function missing_requirement(package)
  local id = package.spec.source.id
  if id:match("^pkg:npm/") and vim.fn.executable("npm") ~= 1 then
    return "npm introuvable"
  end
  if id:match("^pkg:pypi/") and not python_can_create_venvs() then
    return "python3 ne peut pas créer d'environnement virtuel (ensurepip absent)"
  end
end

-- { install = { package... }, skipped = { { name, reason }... } } for the
-- packages that are not installed yet.
function M.plan(registry)
  local plan = { install = {}, skipped = {} }
  for _, name in ipairs(M.packages) do
    local found, package = pcall(registry.get_package, name)
    if not found then
      table.insert(plan.skipped, { name, "absent du registre Mason" })
    elseif provided_outside_mason(name) then
      table.insert(plan.skipped, { name, "déjà fourni hors Mason : " .. vim.fn.exepath(provided_by[name]) })
    elseif not package:is_installed() then
      local reason = missing_requirement(package)
      if reason then
        table.insert(plan.skipped, { name, reason })
      elseif not package:is_installing() then
        table.insert(plan.install, package)
      end
    end
  end
  return plan
end

local function on_installed(name)
  if name == "tree-sitter-cli" then
    require("vle-roux.treesitter").install()
  end
end

function M.ensure_installed()
  -- Headless runs (tests, scripts) must not start downloads.
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return
  end

  registry.refresh(function()
    for _, package in ipairs(M.plan(registry).install) do
      local name = package.name
      vim.schedule(function()
        vim.notify("Mason : installation de " .. name)
      end)
      package:install({}, function(success, err)
        vim.schedule(function()
          if success then
            on_installed(name)
          else
            vim.notify("Mason : échec de " .. name .. " : " .. tostring(err), vim.log.levels.WARN)
          end
        end)
      end)
    end
  end)
end

-- Used by installers: installs everything now and waits, then builds the
-- Treesitter parsers. Returns the number of failures.
function M.install_blocking(timeout_ms)
  timeout_ms = timeout_ms or 30 * 60 * 1000
  local registry = require("mason-registry")
  local refreshed = false
  registry.refresh(function()
    refreshed = true
  end)
  vim.wait(120000, function()
    return refreshed
  end, 100)

  local plan = M.plan(registry)
  for _, skipped in ipairs(plan.skipped) do
    print(("Mason : %s ignoré (%s)"):format(skipped[1], skipped[2]))
  end

  local pending, failures = #plan.install, 0
  for _, package in ipairs(plan.install) do
    print("Mason : installation de " .. package.name)
    package:install({}, function(success, err)
      if success then
        print("Mason : " .. package.name .. " installé")
      else
        failures = failures + 1
        print("Mason : échec de " .. package.name .. " : " .. tostring(err))
      end
      pending = pending - 1
    end)
  end
  vim.wait(timeout_ms, function()
    return pending == 0
  end, 500)
  if pending > 0 then
    failures = failures + pending
    print("Mason : délai dépassé pour " .. pending .. " paquet(s)")
  end

  if not require("vle-roux.treesitter").install({ wait = timeout_ms }) then
    print("Treesitter : CLI tree-sitter absente, parseurs intégrés à Neovim seulement")
  end
  return failures
end

return M
