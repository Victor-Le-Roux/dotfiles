local lazy = require("lazy")

lazy.load({ plugins = { "nvim-lspconfig", "overseer.nvim", "nvim-dap", "blink.cmp" } })

assert(vim.fn.exists(":CHealth") == 2, ":CHealth is missing")
assert(vim.fn.exists(":CConfigure") == 2, ":CConfigure is missing")
assert(vim.fn.exists(":CTest") == 2, ":CTest is missing")
assert(vim.fn.exists(":OverseerRun") == 2, ":OverseerRun is missing")
assert(vim.o.updatetime == 250, "updatetime must remain conservative")

local c_tools = require("vle-roux.c_tools")
assert(vim.fn.executable(c_tools.clangd_command()) == 1, "clangd is unavailable")
if vim.fn.executable("/usr/bin/clangd") == 1 then
  assert(c_tools.clangd_command() == "/usr/bin/clangd", "system clangd must take priority over Mason")
end
assert(vim.lsp.is_enabled("clangd"), "clangd is not enabled")

local blink_config = require("blink.cmp.config")
assert(blink_config.keymap.preset == "default", "blink.cmp keymap preset changed")
assert(blink_config.snippets.preset == "luasnip", "blink.cmp must expand LuaSnip snippets")
assert(vim.lsp.config.basedpyright ~= nil, "basedpyright is not configured")
assert(vim.diagnostic.config().severity_sort == true, "diagnostics are not configured")
assert(vim.fn.exists(":CBear") == 2, ":CBear is missing")
assert(vim.fn.exists(":Norm42") == 2, ":Norm42 is missing")
assert(vim.filetype.match({ filename = "a.h" }) == "c", ".h headers must be C")

local cpp_dir = vim.fn.tempname()
vim.fn.mkdir(cpp_dir .. "/include", "p")
vim.fn.writefile({}, cpp_dir .. "/CMakeLists.txt")
vim.fn.writefile({}, cpp_dir .. "/main.cpp")
assert(vim.filetype.match({ filename = cpp_dir .. "/include/app.h" }) == "cpp", ".h headers of C++ projects must be C++")
vim.fn.writefile({}, cpp_dir .. "/include/util.c")
assert(vim.filetype.match({ filename = cpp_dir .. "/include/app.h" }) == "c", "C sources next to a header keep it C")
vim.fn.delete(cpp_dir, "rf")
assert(vim.fn.exists(":TSInstall") == 2, "nvim-treesitter did not load")

local overseer = require("overseer")
assert(type(overseer.new_task) == "function", "Overseer did not load")

local dap = require("dap")
assert(dap.adapters.codelldb ~= nil, "codelldb adapter is missing")
assert(package.loaded.dapui ~= nil, "nvim-dap-ui did not load")

for _, filetype in ipairs({ "c", "cpp" }) do
  local has_attach = vim.iter(dap.configurations[filetype] or {}):any(function(config)
    return config.type == "codelldb" and config.request == "attach"
  end)
  assert(has_attach, "codelldb attach configuration is missing for " .. filetype)
  local has_launch = vim.iter(dap.configurations[filetype] or {}):any(function(config)
    return config.type == "codelldb" and config.request == "launch"
  end)
  assert(has_launch, "codelldb launch configuration is missing for " .. filetype)
end
assert(dap.adapters.python ~= nil, "debugpy adapter is missing")

-- clangd finds compile_commands.json in build/<preset>/.
local preset_dir = vim.fn.tempname()
vim.fn.mkdir(preset_dir .. "/build/dbg", "p")
vim.fn.writefile({}, preset_dir .. "/CMakeLists.txt")
vim.fn.writefile({ "[]" }, preset_dir .. "/build/dbg/compile_commands.json")
assert(
  c_tools.clangd_init_options(preset_dir).compilationDatabasePath == preset_dir .. "/build/dbg",
  "nested compile_commands.json must reach clangd"
)
vim.fn.delete(preset_dir, "rf")

-- 42 norm: project markers, colorcolumn and single-file build flags.
local norm42 = require("vle-roux.norm42")
local norm_dir = vim.fn.tempname()
vim.fn.mkdir(norm_dir, "p")
local norm_file = norm_dir .. "/main.c"
vim.fn.writefile({
  "/* ************************************************************************** */",
  "/*                                                        :::      ::::::::   */",
  "int main(void) { return (0); }",
}, norm_file)
vim.cmd.edit(norm_file)
local norm_buf = vim.api.nvim_get_current_buf()

local function build_compiler()
  return c_tools.fallback_build_command(norm_buf)[1]
end

assert(norm42.enabled(norm_buf), "the 42 header must enable the norm")
assert(vim.wo.colorcolumn == "81", "norm files need colorcolumn=81")
assert(build_compiler() == "cc", "norm files build with cc -Werror")
assert(vim.tbl_contains(c_tools.fallback_build_command(norm_buf, true), "-g3"), ":DebugBuild must add symbols")

norm42.set_project("off", norm_buf)
assert(not norm42.enabled(norm_buf), ".nonorm42 must disable the norm")
assert(vim.wo.colorcolumn == "", "colorcolumn must be cleared without the norm")
assert(build_compiler() == "gcc", "personal files build with gcc")

vim.g.norm42_project_markers = false
assert(norm42.enabled(norm_buf), "markers must be ignored when disabled")
vim.g.norm42_project_markers = nil

norm42.set_project("clear", norm_buf)
vim.fn.writefile({}, norm_dir .. "/.clang-format")
assert(not norm42.enabled(norm_buf), ".clang-format must disable the norm")
norm42.set_project("on", norm_buf)
assert(norm42.enabled(norm_buf), ".norm42 must win over .clang-format")

require("lazy").load({ plugins = { "conform.nvim", "nvim-lint" } })
assert(require("lint").linters.norminette ~= nil, "norminette linter is missing")
if vim.fn.executable("c_formatter_42") == 1 then
  local formatters = require("conform").list_formatters_to_run(norm_buf)
  assert(formatters[1] and formatters[1].name == "c_formatter_42", "norm files must use c_formatter_42")
end
assert(vim.fn.exists(":FormatOnSave") == 2, ":FormatOnSave is missing")

norm42.toggle_adapt()
assert(vim.wo.colorcolumn == "", "colorcolumn must follow :Norm42Adapt")
assert(build_compiler() == "gcc", "build flags must follow :Norm42Adapt")
norm42.toggle_adapt()
assert(vim.wo.colorcolumn == "81", ":Norm42Adapt must restore colorcolumn")

vim.cmd("bwipeout!")
vim.fn.delete(norm_dir, "rf")

-- Python: an activated conda environment is used, except base.
local python_tools = require("vle-roux.python")
local conda_dir = vim.fn.tempname()
vim.fn.mkdir(conda_dir .. "/bin", "p")
vim.fn.writefile({ "#!/bin/sh" }, conda_dir .. "/bin/python")
vim.fn.setfperm(conda_dir .. "/bin/python", "rwxr-xr-x")
local saved_env = { vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX, vim.env.CONDA_DEFAULT_ENV }
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX, vim.env.CONDA_DEFAULT_ENV = nil, conda_dir, "work"
assert(python_tools.venv_python(nil) == conda_dir .. "/bin/python", "conda environments must be used")
vim.env.CONDA_DEFAULT_ENV = "base"
assert(python_tools.venv_python(nil) == nil, "conda base must not override the system Python")
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX, vim.env.CONDA_DEFAULT_ENV = unpack(saved_env)
vim.fn.delete(conda_dir, "rf")
assert(python_tools.repl_command(0)[1] ~= nil, "Python REPL command is missing")

local startup_picker = vim.api.nvim_get_autocmds({ group = "vle_startup_file_picker", event = "VimEnter" })
assert(#startup_picker == 1, "startup fuzzy file picker is not configured")

print("HEADLESS_C_CONFIG_OK")
