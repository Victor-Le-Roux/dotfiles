-- Colour-only lualine theme that follows vle-roux.theme (light or dark).
local palette = require("vle-roux.theme").palette()
local ui, syntax = palette.ui, palette.syntax

local accents
if palette.light then
  accents = {
    normal = "#35666d",
    insert = "#53673d",
    visual = "#855669",
    replace = "#a5543c",
    command = "#7c573c",
  }
else
  accents = {
    normal = syntax.func,
    insert = syntax.string,
    visual = syntax.number,
    replace = syntax.keyword,
    command = syntax.constant,
  }
end

local function mode(accent)
  return {
    a = { fg = accent, bg = ui.bg, gui = "bold" },
    b = { fg = ui.fg, bg = ui.bg },
    c = { fg = ui.muted, bg = ui.bg },
  }
end

return {
  normal = mode(accents.normal),
  insert = mode(accents.insert),
  visual = mode(accents.visual),
  replace = mode(accents.replace),
  command = mode(accents.command),
  inactive = mode(ui.muted),
}
