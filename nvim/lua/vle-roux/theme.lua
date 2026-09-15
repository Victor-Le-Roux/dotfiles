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
      bg = "#f0e9d8",
      fg = "#3c3e34",
      accent = "#57624b",
      selection = "#e5ddc7",
      visual = "#d8d0b9",
      muted = "#7a7464",
      border = "#b4a78a",
      panel = "#e6decb",
      panel_alt = "#eee7d5",
      search = "#7c573c",
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

local function pick_syntax_palette(kitty, light_theme)
  if light_theme then
    return {
      text = "#3c3e34",
      comment = "#686557",
      keyword = "#873052",
      type = "#894514",
      func = "#006777",
      string = "#38651f",
      number = "#7040a0",
      constant = "#894514",
      preproc = "#873052",
      special = "#006777",
    }
  end

  return {
    text = kitty.foreground or "#e0def4",
    comment = kitty.color15 or "#908caa",
    keyword = kitty.color9 or "#eb6f92",
    type = kitty.color12 or "#9ccfd8",
    func = kitty.color14 or "#9ccfd8",
    string = kitty.color10 or "#9ccfd8",
    number = kitty.color13 or "#c4a7e7",
    constant = kitty.color11 or "#f6c177",
    preproc = kitty.color13 or "#c4a7e7",
    special = kitty.color14 or "#9ccfd8",
  }
end

local function set_hl(group, value)
  vim.api.nvim_set_hl(0, group, value)
end

local function apply_ui_colors(ui)
  set_hl("Normal", { fg = ui.fg, bg = ui.bg })
  set_hl("Cursor", { fg = ui.bg, bg = ui.accent })
  set_hl("lCursor", { fg = ui.bg, bg = ui.accent })
  set_hl("NormalNC", { fg = ui.fg, bg = ui.bg })
  set_hl("SignColumn", { fg = ui.muted, bg = ui.bg })
  set_hl("FoldColumn", { fg = ui.muted, bg = ui.bg })
  set_hl("LineNr", { fg = ui.muted, bg = ui.bg })
  set_hl("CursorLine", { bg = ui.selection })
  set_hl("CursorLineNr", { fg = ui.accent, bg = ui.selection, bold = true })
  set_hl("ColorColumn", { bg = ui.selection })
  set_hl("EndOfBuffer", { fg = ui.bg, bg = ui.bg })
  set_hl("NonText", { fg = ui.muted, bg = ui.bg })
  set_hl("Whitespace", { fg = ui.border, bg = ui.bg })
  set_hl("SpecialKey", { fg = ui.border, bg = ui.bg })
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

local function apply_syntax_colors(syntax)
  -- Keep code readable on the system's light background while reusing the
  -- terminal palette. The same roles are shared by Vim syntax, Treesitter and
  -- clangd semantic tokens, so C files stay consistent whichever highlighter
  -- provides a token.
  set_hl("Comment", { fg = syntax.comment, italic = true })
  set_hl("Constant", { fg = syntax.constant })
  set_hl("String", { fg = syntax.string })
  set_hl("Character", { fg = syntax.string })
  set_hl("Number", { fg = syntax.number })
  set_hl("Float", { fg = syntax.number })
  set_hl("Boolean", { fg = syntax.constant })
  set_hl("Identifier", { fg = syntax.text })
  set_hl("Function", { fg = syntax.func })
  set_hl("Statement", { fg = syntax.keyword })
  set_hl("Conditional", { fg = syntax.keyword })
  set_hl("Repeat", { fg = syntax.keyword })
  set_hl("Label", { fg = syntax.constant })
  set_hl("Operator", { fg = syntax.text })
  set_hl("Keyword", { fg = syntax.keyword })
  set_hl("Exception", { fg = syntax.keyword })
  set_hl("PreProc", { fg = syntax.preproc })
  set_hl("Include", { fg = syntax.preproc })
  set_hl("Define", { fg = syntax.preproc })
  set_hl("Macro", { fg = syntax.preproc })
  set_hl("PreCondit", { fg = syntax.preproc })
  set_hl("Type", { fg = syntax.type })
  set_hl("StorageClass", { fg = syntax.preproc })
  set_hl("Structure", { fg = syntax.type })
  set_hl("Typedef", { fg = syntax.type })
  set_hl("Special", { fg = syntax.special })
  set_hl("SpecialChar", { fg = syntax.special })

  local treesitter_groups = {
    ["@variable"] = { fg = syntax.text },
    ["@variable.builtin"] = { fg = syntax.keyword, italic = true },
    ["@variable.parameter"] = { fg = syntax.text },
    ["@constant"] = { fg = syntax.constant },
    ["@constant.builtin"] = { fg = syntax.constant },
    ["@string"] = { fg = syntax.string },
    ["@string.escape"] = { fg = syntax.special },
    ["@character"] = { fg = syntax.string },
    ["@number"] = { fg = syntax.number },
    ["@number.float"] = { fg = syntax.number },
    ["@boolean"] = { fg = syntax.constant },
    ["@type"] = { fg = syntax.type },
    ["@type.builtin"] = { fg = syntax.type },
    ["@attribute"] = { fg = syntax.preproc },
    ["@property"] = { fg = syntax.text },
    ["@function"] = { fg = syntax.func },
    ["@function.call"] = { fg = syntax.func },
    ["@function.builtin"] = { fg = syntax.func },
    ["@function.macro"] = { fg = syntax.preproc },
    ["@constructor"] = { fg = syntax.type },
    ["@operator"] = { fg = syntax.text },
    ["@keyword"] = { fg = syntax.keyword },
    ["@keyword.return"] = { fg = syntax.keyword },
    ["@keyword.conditional"] = { fg = syntax.keyword },
    ["@keyword.repeat"] = { fg = syntax.keyword },
    ["@keyword.directive"] = { fg = syntax.preproc },
    ["@label"] = { fg = syntax.constant },
    ["@comment"] = { fg = syntax.comment, italic = true },
  }

  for group, value in pairs(treesitter_groups) do
    set_hl(group, value)
  end

  local semantic_groups = {
    namespace = { fg = syntax.type },
    type = { fg = syntax.type },
    class = { fg = syntax.type },
    enum = { fg = syntax.type },
    interface = { fg = syntax.type },
    struct = { fg = syntax.type },
    typeParameter = { fg = syntax.type },
    parameter = { fg = syntax.text },
    variable = { fg = syntax.text },
    property = { fg = syntax.text },
    enumMember = { fg = syntax.constant },
    ["function"] = { fg = syntax.func },
    method = { fg = syntax.func },
    macro = { fg = syntax.preproc },
    modifier = { fg = syntax.keyword },
    comment = { fg = syntax.comment, italic = true },
    string = { fg = syntax.string },
    number = { fg = syntax.number },
    operator = { fg = syntax.text },
  }

  for token, value in pairs(semantic_groups) do
    set_hl("@lsp.type." .. token, value)
  end
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
    apply_syntax_colors(pick_syntax_palette(kitty, light_theme))
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
  apply_syntax_colors(pick_syntax_palette(kitty, light_theme))
end

return M
