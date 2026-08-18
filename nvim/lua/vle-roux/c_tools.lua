local M = {}

local project_markers = {
  "compile_commands.json",
  "compile_flags.txt",
  "CMakePresets.json",
  "CMakeLists.txt",
  "Makefile",
  "makefile",
  ".git",
}

local function readable(path)
  return vim.fn.filereadable(path) == 1
end

local function is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

local function first_line(text)
  return (text or ""):match("[^\r\n]+") or "indisponible"
end

local function command_version(command)
  if not command or vim.fn.executable(command) ~= 1 then
    return "indisponible"
  end

  local result = vim.system({ command, "--version" }, { text = true }):wait()
  if result.code ~= 0 then
    return "erreur (" .. tostring(result.code) .. ")"
  end
  return first_line(result.stdout)
end

local function load_overseer()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.load({ plugins = { "overseer.nvim" } })
  end

  local ok, overseer = pcall(require, "overseer")
  if not ok then
    vim.notify("Overseer est indisponible", vim.log.levels.ERROR)
    return nil
  end
  return overseer
end

local function start_task(name, command, cwd)
  local overseer = load_overseer()
  if not overseer then
    return nil
  end

  local task = overseer.new_task({
    name = name,
    cmd = command[1],
    args = vim.list_slice(command, 2),
    cwd = cwd,
    components = {
      {
        "on_output_quickfix",
        open = false,
        open_on_match = true,
        open_on_exit = "failure",
        close = true,
      },
      "default",
    },
  })
  task:start()
  return task
end

local function cmake_build_directory(root)
  local candidates = {
    root .. "/build",
    root .. "/out",
    root .. "/cmake-build-debug",
    root .. "/cmake-build-release",
  }

  for _, directory in ipairs(candidates) do
    if readable(directory .. "/CMakeCache.txt") then
      return directory
    end
  end

  if is_directory(root) then
    for name, kind in vim.fs.dir(root) do
      if kind == "directory" then
        local directory = root .. "/" .. name
        if readable(directory .. "/CMakeCache.txt") then
          return directory
        end
      end
    end
  end
end

local ignored_source_directories = {
  [".git"] = true,
  [".cache"] = true,
  ["build"] = true,
  ["out"] = true,
  ["cmake-build-debug"] = true,
  ["cmake-build-release"] = true,
}

local function buffer_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr or 0)
  return path ~= "" and vim.fs.normalize(path) or nil
end

local function source_root(bufnr)
  local path = buffer_path(bufnr)
  return path and vim.fs.dirname(path) or vim.uv.cwd()
end

local function has_build_system(root)
  return readable(root .. "/CMakeLists.txt")
    or readable(root .. "/Makefile")
    or readable(root .. "/makefile")
end

local function collect_c_sources(root)
  local sources = {}

  local function scan(directory)
    local ok, iterator = pcall(vim.fs.dir, directory)
    if not ok then
      return
    end

    for name, kind in iterator do
      local path = directory .. "/" .. name
      if kind == "file" and name:match("%.c$") then
        table.insert(sources, vim.fs.normalize(path))
      elseif kind == "directory" and not ignored_source_directories[name] then
        scan(path)
      end
    end
  end

  scan(root)
  table.sort(sources)
  return sources
end

function M.is_c_family(bufnr)
  local filetype = vim.bo[bufnr or 0].filetype
  return filetype == "c" or filetype == "cpp"
end

function M.clangd_command()
  if vim.fn.executable("/usr/bin/clangd") == 1 then
    return "/usr/bin/clangd"
  end

  local executable = vim.fn.exepath("clangd")
  return executable ~= "" and executable or "clangd"
end

function M.project_root(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    path = vim.uv.cwd()
  end
  if not path then
    return nil
  end

  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "file" then
    path = vim.fs.dirname(path)
  end

  return vim.fs.root(path, project_markers)
end

function M.compilation_database(root)
  root = root or M.project_root()
  if not root then
    return nil
  end

  local candidates = {
    root .. "/compile_commands.json",
    root .. "/compile_flags.txt",
    root .. "/build/compile_commands.json",
    root .. "/out/compile_commands.json",
    root .. "/cmake-build-debug/compile_commands.json",
    root .. "/cmake-build-release/compile_commands.json",
  }
  for _, candidate in ipairs(candidates) do
    if readable(candidate) then
      return candidate
    end
  end

  for name, kind in vim.fs.dir(root) do
    if kind == "directory" then
      local candidate = root .. "/" .. name .. "/compile_commands.json"
      if readable(candidate) then
        return candidate
      end
    end
  end
end

function M.clangd_fallback_flags(root)
  if not root or M.compilation_database(root) then
    return {}
  end

  local flags = {}
  for _, name in ipairs({ "include", "inc" }) do
    local directory = root .. "/" .. name
    if is_directory(directory) then
      table.insert(flags, "-I" .. directory)
    end
  end
  return flags
end

function M.check_compilation_database(bufnr)
  if not M.is_c_family(bufnr) then
    return true
  end

  local root = M.project_root(bufnr)
  return not root or M.compilation_database(root) ~= nil
end

function M.fallback_executable(bufnr)
  bufnr = bufnr or 0
  if vim.bo[bufnr].filetype ~= "c" then
    return nil
  end

  local root = source_root(bufnr)
  local path = buffer_path(bufnr)
  if not root or not path or has_build_system(root) then
    return nil
  end

  return root .. "/program"
end

function M.fallback_build_command(bufnr)
  bufnr = bufnr or 0
  local root = source_root(bufnr)
  local output = M.fallback_executable(bufnr)
  if not root or not output then
    return nil
  end

  local sources = collect_c_sources(root)
  if #sources == 0 then
    return nil
  end

  local command = {
    "gcc",
    "-std=c17",
    "-Wall",
    "-Wextra",
    "-O2",
    "-o",
    output,
  }
  vim.list_extend(command, sources)
  return command, root
end

function M.health_data(bufnr)
  bufnr = bufnr or 0
  local root = M.project_root(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })
  local client = clients[1]
  local clangd = M.clangd_command()
  local adapter = vim.fn.exepath("codelldb")

  return {
    root = root or "aucune",
    compilation_database = (root and M.compilation_database(root)) or "absente",
    clangd_command = clangd,
    clangd_version = command_version(clangd),
    clangd_attached = client ~= nil,
    clangd_root = client and client.root_dir or "non attaché",
    codelldb = adapter ~= "" and adapter or "indisponible",
    cmake = command_version("cmake"),
    make = command_version("make"),
    ctest = command_version("ctest"),
  }
end

function M.health(bufnr)
  local data = M.health_data(bufnr)
  local lines = {
    "Racine : " .. data.root,
    "Base de compilation : " .. data.compilation_database,
    "clangd : " .. data.clangd_command,
    "Version : " .. data.clangd_version,
    "Client attaché : " .. tostring(data.clangd_attached),
    "Racine clangd : " .. data.clangd_root,
    "codelldb : " .. data.codelldb,
    "CMake : " .. data.cmake,
    "Make : " .. data.make,
    "CTest : " .. data.ctest,
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "C toolchain health" })
  return data
end

function M.build()
  local root = M.project_root()
  if root then
    local build_directory = cmake_build_directory(root)
    if build_directory then
      start_task("CMake build", { "cmake", "--build", build_directory, "--parallel" }, root)
      return true
    end

    if readable(root .. "/Makefile") or readable(root .. "/makefile") then
      start_task("Make", { "make" }, root)
      return true
    end

    if readable(root .. "/CMakeLists.txt") then
      vim.notify("Le projet CMake n'est pas configuré. Lance :CConfigure puis :Build.", vim.log.levels.WARN)
      return true
    end
  end

  local command, cwd = M.fallback_build_command()
  if command then
    if vim.fn.executable(command[1]) ~= 1 then
      vim.notify("Commande indisponible : " .. command[1], vim.log.levels.ERROR)
      return true
    end
    start_task("GCC build", command, cwd)
    return true
  end

  if vim.bo.filetype ~= "c" then
    return false
  end

  vim.notify("Aucun fichier C à compiler", vim.log.levels.WARN)
  return true
end

function M.configure()
  local root = M.project_root()
  if not root or not readable(root .. "/CMakeLists.txt") then
    vim.notify("Aucun CMakeLists.txt trouvé pour le buffer courant", vim.log.levels.WARN)
    return
  end

  start_task(
    "CMake configure",
    { "cmake", "-S", root, "-B", root .. "/build", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
    root
  )
end

function M.test()
  local root = M.project_root()
  local build_directory = root and cmake_build_directory(root)
  if not root or not build_directory then
    vim.notify("Aucun répertoire CMake configuré pour CTest", vim.log.levels.WARN)
    return
  end

  start_task("CTest", { "ctest", "--test-dir", build_directory, "--output-on-failure" }, root)
end

function M.open_task_picker()
  if load_overseer() then
    vim.cmd("OverseerRun")
  end
end

function M.setup()
  vim.api.nvim_create_user_command("CHealth", function()
    M.health()
  end, { desc = "Inspecter la chaîne d'outils C" })
  vim.api.nvim_create_user_command("CConfigure", M.configure, { desc = "Configurer le projet CMake" })
  vim.api.nvim_create_user_command("CTest", M.test, { desc = "Lancer CTest avec Overseer" })
end

return M
