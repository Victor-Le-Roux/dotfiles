-- Terminal split at the bottom of the editor. fish is the interactive
-- shell when available; 'shell' stays the default (sh) so that system(),
-- :! and plugins do not depend on fish.
local M = {}

local function interactive_shell()
  local fish = vim.fn.exepath("fish")
  return fish ~= "" and fish or vim.o.shell
end

-- `command` is a list or a shell string; nil opens an interactive shell.
function M.open(command, height)
  vim.cmd("botright split")
  vim.cmd("resize " .. (height or 15))
  vim.cmd.enew()
  vim.fn.jobstart(command or { interactive_shell() }, { term = true })
  vim.cmd.startinsert()
end

return M
