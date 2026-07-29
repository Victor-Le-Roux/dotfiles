local lazy = require("lazy")

lazy.load({ plugins = { "nvim-lspconfig", "overseer.nvim", "nvim-dap" } })

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

local cmp_config = require("cmp").get_config()
assert(cmp_config.performance.debounce == 60, "nvim-cmp debounce default changed")
assert(cmp_config.performance.throttle == 30, "nvim-cmp throttle default changed")

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
end

local startup_picker = vim.api.nvim_get_autocmds({ group = "vle_startup_file_picker", event = "VimEnter" })
assert(#startup_picker == 1, "startup fuzzy file picker is not configured")

print("HEADLESS_C_CONFIG_OK")
