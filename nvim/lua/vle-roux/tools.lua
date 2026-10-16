-- External tools installed through Mason, so a fresh machine gets them back.
local M = {}

M.packages = {
  -- C / C++ (clangd and clang-format come from the system when available)
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
    for _, name in ipairs(M.packages) do
      local found, package = pcall(registry.get_package, name)
      if found and not package:is_installed() and not package:is_installing() then
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
    end
  end)
end

return M
