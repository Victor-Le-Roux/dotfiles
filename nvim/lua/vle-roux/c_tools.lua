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

  local ok, result = pcall(function()
    return vim.system({ command, "--version" }, { text = true }):wait(2000)
  end)
  if not ok then
    return "erreur"
  end
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

local function start_task(name, command, cwd, on_success)
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
  if on_success then
    task:subscribe("on_complete", function(_, status)
      if status == overseer.STATUS.SUCCESS then
        vim.schedule(on_success)
      end
      return true
    end)
  end
  task:start()
  return task
end

-- Shared with commands.lua (single-file C++ builds).
M.start_task = start_task

local function restart_clangd()
  if vim.fn.exists(":LspRestart") == 2 then
    pcall(vim.cmd, "LspRestart clangd")
  else
    pcall(vim.cmd, "lsp restart clangd")
  end
end

-- Subdirectories of `directory` holding `file`, e.g. build/<preset>/.
local function find_in_subdirectories(directory, file)
  if not is_directory(directory) then
    return nil
  end
  for name, kind in vim.fs.dir(directory) do
    if kind == "directory" then
      local candidate = directory .. "/" .. name .. "/" .. file
      if readable(candidate) then
        return candidate
      end
    end
  end
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

  local cache = find_in_subdirectories(root, "CMakeCache.txt")
    or find_in_subdirectories(root .. "/build", "CMakeCache.txt")
  return cache and vim.fs.dirname(cache)
end

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

-- Only the buffer's own directory: sibling exercises (ex00/, ex01/...) each
-- have their own main() and must not be linked together.
local function collect_c_sources(root)
  local sources = {}

  local ok, iterator = pcall(vim.fs.dir, root)
  if not ok then
    return sources
  end

  for name, kind in iterator do
    if kind == "file" and name:match("%.c$") then
      table.insert(sources, vim.fs.normalize(root .. "/" .. name))
    end
  end

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

  return find_in_subdirectories(root, "compile_commands.json")
    or find_in_subdirectories(root .. "/build", "compile_commands.json")
end

-- clangd only looks in the root and build/: point it at build/<preset>/ and
-- other nested directories.
function M.clangd_init_options(root)
  local options = {}
  local flags = M.clangd_fallback_flags(root)
  if #flags > 0 then
    options.fallbackFlags = flags
  end

  local database = root and M.compilation_database(root)
  if database and vim.fs.basename(database) == "compile_commands.json" then
    options.compilationDatabasePath = vim.fs.dirname(database)
  end
  return options
end

function M.clangd_fallback_flags(root)
  if not root or M.compilation_database(root) then
    return {}
  end

  local flags = {}
  -- includes/ and libft/ follow the usual 42 project layout.
  for _, name in ipairs({ "include", "inc", "includes", "libft", "libft/include", "libft/includes" }) do
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

-- `debug` swaps the optimisation for symbols, so DAP can step through.
function M.fallback_build_command(bufnr, debug)
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

  local norm42 = require("vle-roux.norm42")
  local command
  if norm42.adapt_enabled() and norm42.enabled(bufnr) then
    -- Same flags as the 42 correction.
    command = { "cc", "-Wall", "-Wextra", "-Werror" }
  else
    command = { "gcc", "-std=c17", "-Wall", "-Wextra", not debug and "-O2" or nil }
  end
  if debug then
    vim.list_extend(command, { "-g3", "-O0" })
  end
  vim.list_extend(command, { "-o", output })
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

function M.build(opts)
  opts = opts or {}
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

  local command, cwd = M.fallback_build_command(0, opts.debug)
  if command then
    if vim.fn.executable(command[1]) ~= 1 then
      vim.notify("Commande indisponible : " .. command[1], vim.log.levels.ERROR)
      return true
    end
    start_task(opts.debug and "GCC debug build" or "GCC build", command, cwd, opts.on_success)
    return true
  end

  if vim.bo.filetype ~= "c" then
    return false
  end

  vim.notify("Aucun fichier C à compiler", vim.log.levels.WARN)
  return true
end

local function configure_presets(root)
  local path = root .. "/CMakePresets.json"
  if not readable(path) then
    return {}
  end

  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(data) ~= "table" then
    vim.notify("CMakePresets.json illisible", vim.log.levels.WARN)
    return {}
  end

  local names = {}
  for _, preset in ipairs(data.configurePresets or {}) do
    if not preset.hidden then
      table.insert(names, preset.name)
    end
  end
  return names
end

-- `:CConfigure [Debug|Release|...]`: presets when the project has some,
-- otherwise build/ in Debug (Ninja for a fresh build directory).
function M.configure(opts)
  local build_type = opts and opts.args ~= "" and opts.args or nil
  local root = M.project_root()
  if not root or not readable(root .. "/CMakeLists.txt") then
    vim.notify("Aucun CMakeLists.txt trouvé pour le buffer courant", vim.log.levels.WARN)
    return
  end

  local function run(name, command)
    if build_type then
      table.insert(command, "-DCMAKE_BUILD_TYPE=" .. build_type)
    end
    start_task(name, command, root, restart_clangd)
  end

  local presets = configure_presets(root)
  local function run_preset(preset)
    if preset then
      run("CMake configure (" .. preset .. ")", { "cmake", "--preset", preset, "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" })
    end
  end
  if #presets == 1 then
    run_preset(presets[1])
    return
  elseif #presets > 1 then
    vim.ui.select(presets, { prompt = "Preset CMake" }, run_preset)
    return
  end

  local build_directory = root .. "/build"
  local command = { "cmake", "-S", root, "-B", build_directory, "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
  build_type = build_type or "Debug"
  -- The generator of an existing build directory cannot change.
  if vim.fn.executable("ninja") == 1 and not readable(build_directory .. "/CMakeCache.txt") then
    vim.list_extend(command, { "-G", "Ninja" })
  end
  run("CMake configure", command)
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

local function makefile(root)
  for _, name in ipairs({ "Makefile", "makefile" }) do
    if readable(root .. "/" .. name) then
      return root .. "/" .. name
    end
  end
end

-- The NAME variable of 42 Makefiles is the produced executable.
local function makefile_target(root)
  local path = makefile(root)
  if not path then
    return nil
  end
  for _, line in ipairs(vim.fn.readfile(path, "", 200)) do
    local name = line:match("^%s*NAME%s*[:+]?=%s*(%S+)")
    if name then
      return name
    end
  end
end

-- Program and arguments are remembered between debug and valgrind runs.
M.last_program = nil
M.last_args = nil

function M.default_program(root)
  if M.last_program then
    return M.last_program
  end

  local fallback = M.fallback_executable()
  if fallback then
    return fallback
  end

  root = root or M.project_root()
  local target = root and makefile_target(root)
  if target then
    return root .. "/" .. target
  end
  return (root or vim.uv.cwd()) .. "/"
end

function M.dap_program()
  local path = vim.fn.input({ prompt = "Programme : ", default = M.default_program(), completion = "file" })
  if path == "" then
    return require("dap").ABORT
  end
  M.last_program = vim.fn.fnamemodify(path, ":p")
  return M.last_program
end

function M.dap_args()
  M.last_args = vim.fn.input({ prompt = "Arguments : ", default = M.last_args or "" })
  return vim.split(M.last_args, "%s+", { trimempty = true })
end

-- Generates compile_commands.json for Makefile projects so clangd knows the
-- real flags and include paths. compiledb (pip) replaces bear where it
-- cannot be installed, e.g. without root on 42 workstations.
function M.bear()
  local root = M.project_root()
  if not root or not makefile(root) then
    vim.notify("Aucun Makefile trouvé pour le buffer courant", vim.log.levels.WARN)
    return
  end

  local name, command
  if vim.fn.executable("bear") == 1 then
    name, command = "Bear", { "bear", "--", "make", "-B" }
  elseif vim.fn.executable("compiledb") == 1 then
    name, command = "compiledb", { "compiledb", "make", "-B" }
  else
    vim.notify("Commande indisponible : bear ou compiledb", vim.log.levels.ERROR)
    return
  end

  start_task(name, command, root, function()
    restart_clangd()
    vim.notify("compile_commands.json généré, clangd relancé")
  end)
end

local quickfix_components = {
  { "on_output_quickfix", open_on_exit = "failure" },
  "default",
}

local function shell_join(words)
  return table.concat(vim.tbl_map(vim.fn.shellescape, words), " ")
end

local function program_params(root)
  return {
    program = { type = "string", name = "Programme", default = M.default_program(root), order = 1 },
    args = { type = "string", name = "Arguments", default = M.last_args or "", optional = true, order = 2 },
  }
end

local function remember(params)
  M.last_program = vim.fn.fnamemodify(params.program, ":p")
  M.last_args = params.args or ""
  return M.last_program, vim.split(M.last_args, "%s+", { trimempty = true })
end

local function c_templates(root)
  local templates = {}

  if makefile(root) then
    for _, target in ipairs({ "re", "clean", "fclean" }) do
      table.insert(templates, {
        name = "make " .. target,
        builder = function()
          return { cmd = { "make", target }, cwd = root, components = quickfix_components }
        end,
      })
    end

    table.insert(templates, {
      name = "make && lancer",
      params = program_params(root),
      builder = function(params)
        local program, args = remember(params)
        return {
          cmd = "make && " .. shell_join(vim.list_extend({ program }, args)),
          cwd = root,
          components = quickfix_components,
        }
      end,
    })
  end

  if vim.fn.executable("norminette") == 1 then
    table.insert(templates, {
      name = "norminette",
      builder = function()
        return { cmd = { "norminette" }, cwd = root }
      end,
    })
  end

  if vim.fn.executable("valgrind") == 1 then
    table.insert(templates, {
      name = "valgrind",
      params = program_params(root),
      builder = function(params)
        local program, args = remember(params)
        local command = {
          "valgrind",
          "--leak-check=full",
          "--show-leak-kinds=all",
          "--track-origins=yes",
          program,
        }
        return { cmd = vim.list_extend(command, args), cwd = root }
      end,
    })
  end

  return templates
end

function M.register_templates()
  require("overseer").register_template({
    name = "vle-roux C",
    generator = function(search)
      local root = vim.fs.root(search.dir, project_markers)
      if not root then
        return {}
      end
      return c_templates(root)
    end,
  })
end

local cpp_extensions = { cpp = true, cc = true, cxx = true, ["c++"] = true, hpp = true, hh = true, hxx = true }

local function directory_language(directory)
  local has_c, has_cpp = false, false
  local ok, iterator = pcall(vim.fs.dir, directory)
  if not ok then
    return nil
  end

  for name, kind in iterator do
    if kind == "file" then
      local extension = name:match("%.([^.]+)$")
      if extension == "c" then
        has_c = true
      elseif cpp_extensions[extension] then
        has_cpp = true
      end
    end
  end

  if has_c then
    return "c"
  end
  if has_cpp then
    return "cpp"
  end
end

-- A header is C++ when the sources next to it (its directory, the parent,
-- the project root, then root/src) are C++ only. C wins in mixed or empty
-- places, which keeps 42 projects in C. Override with :set filetype=cpp.
function M.header_filetype(path)
  local directory = vim.fn.fnamemodify(path, ":p:h")
  local root = vim.fs.root(directory, project_markers)
  local candidates = { directory, vim.fs.dirname(directory) }
  if root then
    vim.list_extend(candidates, { root, root .. "/src" })
  end

  local seen = {}
  for _, candidate in ipairs(candidates) do
    if not seen[candidate] then
      seen[candidate] = true
      local language = directory_language(candidate)
      if language then
        return language
      end
    end
  end
  return "c"
end

function M.setup()
  vim.filetype.add({
    extension = {
      h = function(path)
        return M.header_filetype(path)
      end,
    },
  })
  vim.api.nvim_create_user_command("CBear", M.bear, { desc = "Générer compile_commands.json avec bear" })
  vim.api.nvim_create_user_command("CHealth", function()
    M.health()
  end, { desc = "Inspecter la chaîne d'outils C" })
  vim.api.nvim_create_user_command("CConfigure", M.configure, {
    nargs = "?",
    complete = function()
      return { "Debug", "Release", "RelWithDebInfo", "MinSizeRel" }
    end,
    desc = "Configurer le projet CMake (Debug par défaut)",
  })
  vim.api.nvim_create_user_command("CTest", M.test, { desc = "Lancer CTest avec Overseer" })
end

return M
