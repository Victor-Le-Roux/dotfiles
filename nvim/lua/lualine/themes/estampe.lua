-- Colour-only lualine theme. All sections, counters and diagnostics remain configured.
local paper = "#f0e9d8"
local ink = "#3c3e34"
local muted = "#7a7464"
local function mode(accent)
  return {
    a = { fg = accent, bg = paper, gui = "bold" },
    b = { fg = ink, bg = paper },
    c = { fg = muted, bg = paper },
  }
end
return {
  normal = mode("#35666d"),
  insert = mode("#53673d"),
  visual = mode("#855669"),
  replace = mode("#a5543c"),
  command = mode("#7c573c"),
  inactive = mode(muted),
}
