-- External tools installed through Mason, so a fresh machine gets them back.
-- A package is skipped when the tool already exists outside Mason (system
-- clangd, pip-installed basedpyright...) or when Mason cannot install it
-- here: npm packages need npm, pypi ones need `python3 -m venv` with
-- ensurepip (missing on Ubuntu without python3-venv, e.g. 42 workstations).
local M = {}

M.full_packages = {
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

-- Light profile: clangd only. Python tools come from pip (installer), the
-- tree-sitter CLI is only needed while building parsers, and codelldb is
-- kept when it was installed on purpose.
M.light_packages = { "clangd" }

M.packages = vim.g.vle_light and M.light_packages or M.full_packages

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

  failures = failures + M.build_parsers(registry, timeout_ms)
  return failures
end

-- Uninstalls the Mason packages outside the current profile, except the
-- names in `keep` (e.g. codelldb). Returns the removed names.
function M.prune(keep)
  local registry = require("mason-registry")
  local wanted = {}
  for _, name in ipairs(vim.list_extend(vim.list_extend({}, M.packages), keep or {})) do
    wanted[name] = true
  end

  local removed, pending = {}, 0
  for _, package in ipairs(registry.get_installed_packages()) do
    if not wanted[package.name] then
      pending = pending + 1
      table.insert(removed, package.name)
      package:uninstall({}, function()
        pending = pending - 1
      end)
    end
  end
  vim.wait(120000, function()
    return pending == 0
  end, 200)
  return removed
end

-- Builds the Treesitter parsers. In the light profile the tree-sitter CLI
-- is installed for the build only, then removed to save space.
function M.build_parsers(registry, timeout_ms)
  local cli = registry.get_package("tree-sitter-cli")
  local temporary = vim.g.vle_light and vim.fn.executable("tree-sitter") ~= 1
  if temporary then
    local done, ok = false, false
    cli:install({}, function(success)
      ok, done = success, true
    end)
    vim.wait(timeout_ms, function()
      return done
    end, 500)
    if not ok then
      print("Treesitter : CLI tree-sitter impossible à installer, parseurs intégrés à Neovim seulement")
      return 1
    end
  end

  local built = require("vle-roux.treesitter").install({ wait = timeout_ms })
  if not built then
    print("Treesitter : CLI tree-sitter absente, parseurs intégrés à Neovim seulement")
  end

  if temporary then
    local removed = false
    cli:uninstall({}, function()
      removed = true
    end)
    vim.wait(60000, function()
      return removed
    end, 200)
  end
  return built and 0 or 1
end

return M
