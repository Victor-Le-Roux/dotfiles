local M = {}

local function hex_luminance(hex)
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
end

local function read_kitty_palette()
  local palette = {}
  local theme_file = vim.fn.expand("~/.config/kitty/theme.conf")
  if vim.fn.filereadable(theme_file) == 0 then
    return palette
  end

  for _, line in ipairs(vim.fn.readfile(theme_file)) do
    local key, hex = line:match("^%s*([%w_]+)%s+#(%x%x%x%x%x%x)")
    if key and hex then
      palette[key] = "#" .. hex:lower()
    end
  end

  return palette
end

local function pick_ui_palette(kitty, light_theme)
  if light_theme then
    return {
      bg = kitty.background or "#e8e3d3",
      fg = kitty.foreground or "#1b1f2a",
      accent = kitty.cursor or "#2f9caf",
      selection = kitty.selection_background or "#d8d2bf",
      visual = "#c8dadd",
      muted = kitty.color8 or "#6a6558",
      border = "#bdb7a6",
      panel = "#ece7d8",
      panel_alt = "#f3efe4",
      search = "#79aeb9",
    }
  end

  return {
    bg = kitty.background or "#1f1d2e",
    fg = kitty.foreground or "#e0def4",
    accent = kitty.cursor or "#9ccfd8",
    selection = kitty.selection_background or "#2a273f",
    visual = "#393552",
    muted = kitty.color8 or "#908caa",
    border = "#403d52",
    panel = "#26233a",
    panel_alt = "#232136",
    search = "#31748f",
  }
end

local function set_hl(group, value)
  vim.api.nvim_set_hl(0, group, value)
end

local function apply_ui_colors(ui)
  set_hl("Normal", { fg = ui.fg, bg = ui.bg })
  set_hl("NormalNC", { fg = ui.fg, bg = ui.bg })
  set_hl("SignColumn", { fg = ui.muted, bg = ui.bg })
  set_hl("FoldColumn", { fg = ui.muted, bg = ui.bg })
  set_hl("LineNr", { fg = ui.muted, bg = ui.bg })
  set_hl("CursorLine", { bg = ui.selection })
  set_hl("CursorLineNr", { fg = ui.accent, bg = ui.selection, bold = true })
  set_hl("ColorColumn", { bg = ui.selection })
  set_hl("EndOfBuffer", { fg = ui.bg, bg = ui.bg })
  set_hl("NonText", { fg = ui.muted, bg = ui.bg })
  set_hl("WinSeparator", { fg = ui.border, bg = ui.bg })
  set_hl("VertSplit", { fg = ui.border, bg = ui.bg })
  set_hl("StatusLine", { fg = ui.fg, bg = ui.panel })
  set_hl("StatusLineNC", { fg = ui.muted, bg = ui.panel_alt })
  set_hl("TabLine", { fg = ui.muted, bg = ui.panel_alt })
  set_hl("TabLineSel", { fg = ui.fg, bg = ui.panel })
  set_hl("TabLineFill", { bg = ui.panel_alt })
  set_hl("NormalFloat", { fg = ui.fg, bg = ui.panel_alt })
  set_hl("FloatBorder", { fg = ui.border, bg = ui.panel_alt })
  set_hl("Pmenu", { fg = ui.fg, bg = ui.panel_alt })
  set_hl("PmenuSel", { fg = ui.fg, bg = ui.selection })
  set_hl("PmenuSbar", { bg = ui.selection })
  set_hl("PmenuThumb", { bg = ui.muted })
  set_hl("Visual", { bg = ui.visual })
  set_hl("Search", { fg = ui.bg, bg = ui.search })
  set_hl("IncSearch", { fg = ui.bg, bg = ui.accent, bold = true })
  set_hl("CurSearch", { fg = ui.bg, bg = ui.accent, bold = true })
  set_hl("MatchParen", { fg = ui.accent, bg = ui.selection, bold = true })
  set_hl("Directory", { fg = ui.accent, bold = true })
  set_hl("Title", { fg = ui.fg, bold = true })

  set_hl("NvimTreeNormal", { fg = ui.fg, bg = ui.bg })
  set_hl("NvimTreeNormalNC", { fg = ui.fg, bg = ui.bg })
  set_hl("NvimTreeWinSeparator", { fg = ui.border, bg = ui.bg })
  set_hl("NvimTreeRootFolder", { fg = ui.accent, bold = true })

  set_hl("TelescopeNormal", { fg = ui.fg, bg = ui.panel_alt })
  set_hl("TelescopeBorder", { fg = ui.border, bg = ui.panel_alt })
  set_hl("TelescopePromptNormal", { fg = ui.fg, bg = ui.panel })
  set_hl("TelescopePromptBorder", { fg = ui.border, bg = ui.panel })
  set_hl("TelescopeSelection", { bg = ui.selection })
end

function M.setup()
  local kitty = read_kitty_palette()
  local light_theme = true
  if kitty.background then
    light_theme = hex_luminance(kitty.background) > 140
  end

  local ok, rose_pine = pcall(require, "rose-pine")
  if not ok then
    vim.o.background = light_theme and "light" or "dark"
    vim.cmd("colorscheme habamax")
    apply_ui_colors(pick_ui_palette(kitty, light_theme))
    return
  end

  vim.o.background = light_theme and "light" or "dark"

  rose_pine.setup({
    variant = light_theme and "dawn" or "moon",
    dark_variant = "moon",
    disable_background = false,
    disable_float_background = false,
    styles = {
      transparency = false,
    },
    highlight_groups = {
      CursorLine = { bg = light_theme and "#d8d2bf" or "#2a273f" },
      CursorLineNr = { fg = "#2f9caf", bold = true },
      Visual = { bg = light_theme and "#c8dadd" or "#393552" },
      Search = { bg = "#79aeb9", fg = light_theme and "#1b1f2a" or "#191724" },
      IncSearch = { bg = "#2f9caf", fg = light_theme and "#e8e3d3" or "#e0def4" },
    },
  })

  vim.cmd("colorscheme rose-pine")
  apply_ui_colors(pick_ui_palette(kitty, light_theme))
end

return M
