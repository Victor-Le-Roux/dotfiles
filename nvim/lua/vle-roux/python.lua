local M = {}

-- Also used by the Python language servers, so they share :Run's root.
local root_markers = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  ".venv",
  "venv",
  ".git",
}
M.root_markers = root_markers

local venv_directories = { ".venv", "venv", "env" }

local function executable(path)
  return path and vim.fn.executable(path) == 1
end

function M.project_root(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr or 0)
  if path == "" then
    path = vim.uv.cwd()
  end
  return vim.fs.root(path, root_markers)
end

local poetry_cache = {}

-- Poetry keeps its environments outside the project by default.
local function poetry_python(root)
  if poetry_cache[root] ~= nil then
    return poetry_cache[root] or nil
  end

  poetry_cache[root] = false
  local pyproject = root .. "/pyproject.toml"
  if vim.fn.executable("poetry") ~= 1 or vim.fn.filereadable(pyproject) ~= 1 then
    return nil
  end
  local uses_poetry = vim.iter(vim.fn.readfile(pyproject)):any(function(line)
    return line:match("^%[tool%.poetry") ~= nil
  end)
  if not uses_poetry then
    return nil
  end

  local ok, result = pcall(function()
    return vim.system({ "poetry", "env", "info", "--path" }, { cwd = root, text = true }):wait(3000)
  end)
  if ok and result.code == 0 then
    local python = vim.trim(result.stdout or "") .. "/bin/python"
    if executable(python) then
      poetry_cache[root] = python
      return python
    end
  end
end

-- Order: the project's .venv/venv/env (uv and most tools create .venv),
-- Poetry's environment, the activated venv ($VIRTUAL_ENV), then an
-- activated conda environment other than base.
function M.venv_python(root)
  if root then
    for _, name in ipairs(venv_directories) do
      local python = root .. "/" .. name .. "/bin/python"
      if executable(python) then
        return python
      end
    end

    local python = poetry_python(root)
    if python then
      return python
    end
  end

  if vim.env.VIRTUAL_ENV then
    local python = vim.env.VIRTUAL_ENV .. "/bin/python"
    if executable(python) then
      return python
    end
  end

  if vim.env.CONDA_PREFIX and vim.env.CONDA_DEFAULT_ENV ~= "base" then
    local python = vim.env.CONDA_PREFIX .. "/bin/python"
    if executable(python) then
      return python
    end
  end
end

-- The project's environment, otherwise the system python3 (with the
-- packages of `pip install --user`).
function M.root_interpreter(root)
  local python = M.venv_python(root)
  if python then
    return python
  end

  local system_python = vim.fn.exepath("python3")
  return system_python ~= "" and system_python or nil
end

function M.interpreter(bufnr)
  return M.root_interpreter(M.project_root(bufnr))
end

-- A command of the project's environment (flake8, mypy...), otherwise the
-- one on PATH. With `project_only`, only the environment's.
function M.tool(root, name, project_only)
  local python = M.venv_python(root)
  if python then
    local path = vim.fs.dirname(python) .. "/" .. name
    if executable(path) then
      return path
    end
  end
  if project_only then
    return nil
  end
  local path = vim.fn.exepath(name)
  return path ~= "" and path or nil
end

local function has_ruff_config(name, directory)
  if name == "ruff.toml" or name == ".ruff.toml" then
    return true
  end
  if name ~= "pyproject.toml" then
    return false
  end
  local ok, lines = pcall(vim.fn.readfile, directory .. "/" .. name)
  return ok and vim.iter(lines):any(function(line)
    return line:match("^%[tool%.ruff") ~= nil
  end)
end

-- `path` is a file or a directory.
function M.uses_ruff(path)
  return path ~= nil and path ~= "" and vim.fs.root(path, has_ruff_config) ~= nil
end

-- 42's Python projects are checked with flake8: it lints when installed,
-- except in projects configured for ruff. Otherwise the ruff server lints.
function M.linter(path, root)
  if not M.uses_ruff(path ~= "" and path or root) and M.tool(root, "flake8") then
    return "flake8"
  end
  return "ruff"
end

-- flake8's max-line-length from its configuration at the root, otherwise
-- flake8's default (79).
function M.flake8_line_length(root)
  for _, name in ipairs({ ".flake8", "setup.cfg", "tox.ini" }) do
    local path = root and root .. "/" .. name
    if path and vim.fn.filereadable(path) == 1 then
      local in_section = false
      for _, line in ipairs(vim.fn.readfile(path)) do
        local section = line:match("^%s*%[(.-)%]")
        if section then
          in_section = section == "flake8"
        elseif in_section then
          local length = line:match("^%s*max[-_]line[-_]length%s*[=:]%s*(%d+)")
          if length then
            return tonumber(length)
          end
        end
      end
    end
  end
  return 79
end

-- Line length for ruff format when flake8 checks the buffer: ruff's 88
-- would produce lines flake8 rejects. nil keeps ruff's own settings.
function M.format_line_length(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local root = M.project_root(bufnr)
  if M.linter(path, root) == "flake8" then
    return M.flake8_line_length(root)
  end
end

-- flake8 (see M.linter) and mypy when the project's environment has it;
-- nvim-lint runs them from the project root, where their configuration is.
function M.lint(bufnr)
  local ok, lint = pcall(require, "lint")
  if not ok or not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "python" then
    return
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local root = M.project_root(bufnr)
  local commands = {
    flake8 = M.linter(path, root) == "flake8" and M.tool(root, "flake8") or nil,
    -- mypy reads the file on disk.
    mypy = vim.fn.filereadable(path) == 1 and M.tool(root, "mypy", true) or nil,
  }
  for _, name in ipairs({ "flake8", "mypy" }) do
    local command = commands[name]
    if command then
      vim.api.nvim_buf_call(bufnr, function()
        lint.try_lint(name, {
          cwd = root or vim.fs.dirname(path),
          wrap_linter = function(linter)
            linter.cmd = command
            return linter
          end,
        })
      end)
    else
      vim.diagnostic.reset(lint.get_namespace(name), bufnr)
    end
  end
end

local language_servers = { "jedi_language_server", "basedpyright", "ruff" }

-- The servers read the interpreter when they start.
local function restart_language_servers()
  for _, name in ipairs(language_servers) do
    if #vim.lsp.get_clients({ name = name }) > 0 then
      vim.cmd("lsp restart " .. name)
    end
  end
end

local function run(command, opts, on_done)
  local ok, err = pcall(vim.system, command, vim.tbl_extend("force", { text = true }, opts or {}), function(result)
    vim.schedule(function()
      on_done(result.code == 0, vim.trim((result.stderr or "") .. "\n" .. (result.stdout or "")))
    end)
  end)
  if not ok then
    on_done(false, tostring(err))
  end
end

local function python_can_create_venvs(python)
  local ok, result = pcall(function()
    return vim.system({ python, "-c", "import ensurepip, venv" }):wait(5000)
  end)
  return ok and result.code == 0
end

local virtualenv_url = "https://bootstrap.pypa.io/virtualenv.pyz"

-- `python3 -m venv` needs ensurepip, missing on Ubuntu without python3-venv
-- (42 workstations): virtualenv's zipapp is then downloaded to a temporary
-- directory, which also holds virtualenv's cache, so only the environment
-- stays in the home.
local function create_environment(python, venv, on_done)
  if python_can_create_venvs(python) then
    run({ python, "-m", "venv", venv }, nil, on_done)
    return
  end

  local temporary = vim.fn.tempname()
  vim.fn.mkdir(temporary, "p")
  local zipapp = temporary .. "/virtualenv.pyz"
  local download
  if vim.fn.executable("curl") == 1 then
    download = { "curl", "-fsSL", "-o", zipapp, virtualenv_url }
  elseif vim.fn.executable("wget") == 1 then
    download = { "wget", "-q", "-O", zipapp, virtualenv_url }
  else
    vim.fn.delete(temporary, "rf")
    on_done(false, "ni curl ni wget pour télécharger virtualenv")
    return
  end

  local function finish(ok, output)
    vim.fn.delete(temporary, "rf")
    on_done(ok, output)
  end
  run(download, nil, function(ok, output)
    if not ok then
      finish(false, "téléchargement de virtualenv impossible : " .. output)
      return
    end
    run({ python, zipapp, "--quiet", "--no-setuptools", "--no-wheel", "--app-data", temporary .. "/data", venv }, nil, finish)
  end)
end

-- :PyVenv creates .venv at the project root (the current directory when
-- there is no project), installs requirements.txt there, then restarts the
-- language servers so they use it.
function M.create_venv(bufnr, on_done)
  on_done = on_done or function() end
  local root = M.project_root(bufnr) or vim.uv.cwd()
  local venv = root .. "/.venv"
  if executable(venv .. "/bin/python") then
    vim.notify(venv .. " existe déjà")
    on_done(true)
    return
  end

  local python = vim.fn.exepath("python3")
  if python == "" then
    vim.notify("python3 introuvable", vim.log.levels.ERROR)
    on_done(false)
    return
  end

  local function fail(message)
    vim.notify(message, vim.log.levels.ERROR)
    on_done(false)
  end
  local function done()
    restart_language_servers()
    vim.notify(venv .. " prêt (paquets : " .. venv .. "/bin/pip install <paquet>)")
    on_done(true)
  end

  vim.notify("Création de " .. venv)
  create_environment(python, venv, function(ok, output)
    if not ok then
      vim.fn.delete(venv, "rf")
      fail("Environnement impossible à créer : " .. output)
      return
    end
    local requirements = root .. "/requirements.txt"
    if vim.fn.filereadable(requirements) ~= 1 then
      done()
      return
    end
    vim.notify("Installation de " .. requirements)
    -- No pip cache: it would stay in the home.
    run(
      { venv .. "/bin/python", "-m", "pip", "install", "--disable-pip-version-check", "-r", requirements },
      { cwd = root, env = { PIP_NO_CACHE_DIR = "1" } },
      function(installed, pip_output)
        if not installed then
          fail("pip n'a pas pu installer requirements.txt : " .. pip_output)
          return
        end
        done()
      end
    )
  end)
end

-- Checking for IPython starts Python (slow): once per interpreter.
local ipython_cache = {}

local function has_ipython(python)
  if ipython_cache[python] == nil then
    local ok, result = pcall(function()
      return vim.system({ python, "-c", "import IPython" }):wait(3000)
    end)
    ipython_cache[python] = ok and result.code == 0
  end
  return ipython_cache[python]
end

-- IPython from the same environment when it is installed there.
function M.repl_command(bufnr)
  local python = M.interpreter(bufnr) or "python3"
  if has_ipython(python) then
    return { python, "-m", "IPython", "--no-autoindent" }
  end
  return { python }
end

return M
