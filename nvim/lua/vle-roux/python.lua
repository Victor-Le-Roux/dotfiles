local M = {}

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

function M.interpreter(bufnr)
  local python = M.venv_python(M.project_root(bufnr))
  if python then
    return python
  end

  local system_python = vim.fn.exepath("python3")
  return system_python ~= "" and system_python or nil
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
