local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Impossible de cloner lazy.nvim :\n", "ErrorMsg" },
      { output, "WarningMsg" },
    }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { import = "vle-roux.plugins" },
}, {
  -- No plugin needs luarocks; this also silences its :checkhealth warning.
  rocks = { enabled = false },
  change_detection = {
    notify = false,
  },
})
