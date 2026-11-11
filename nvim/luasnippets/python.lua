-- Python snippets, in place of vim-snippets' (completion.lua): typed
-- signatures, `self`/`cls` only inside a class, __init__ that assigns its
-- parameters. <C-l>/<C-h> move between fields.

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

-- The first parameter of a function defined at the snippet's line: "self"
-- or "cls" in a class body (from the decorators just above), otherwise "".
local function receiver(snip)
  local row = tonumber(snip.env.TM_LINE_INDEX) + 1
  local indent = vim.fn.indent(row)
  if indent <= 0 then
    return ""
  end

  local decorator
  local just_above = true
  for lnum = row - 1, 1, -1 do
    local line = vim.fn.getline(lnum)
    if line:match("%S") and not line:match("^%s*#") then
      local line_indent = vim.fn.indent(lnum)
      if line_indent < indent then
        if not line:match("^%s*class[%s:(]") or decorator == "staticmethod" then
          return ""
        end
        return decorator == "classmethod" and "cls" or "self"
      end
      if just_above and line_indent == indent and line:match("^%s*@") then
        decorator = decorator or line:match("^%s*@([%w_]+)%s*$")
      else
        just_above = false
      end
    end
  end
  return ""
end

local function parameters()
  return d(2, function(_, parent)
    return sn(nil, { i(1, receiver(parent.snippet)) })
  end)
end

-- Splits "a: int, b: dict[str, int] = {}" on the top-level commas.
local function split_parameters(text)
  local parts, depth, start = {}, 0, 1
  for position = 1, #text do
    local char = text:sub(position, position)
    if char:match("[%[(%{]") then
      depth = depth + 1
    elseif char:match("[%])%}]") then
      depth = depth - 1
    elseif char == "," and depth == 0 then
      table.insert(parts, text:sub(start, position - 1))
      start = position + 1
    end
  end
  table.insert(parts, text:sub(start))
  return parts
end

-- One `self.name = name` per parameter, then the cursor's line.
local function assignments(args)
  local lines = {}
  for _, part in ipairs(split_parameters(table.concat(args[1], " "))) do
    local name = vim.trim(part):match("^%**([%a_][%w_]*)")
    if name and name ~= "self" then
      table.insert(lines, (#lines == 0 and "" or "\t") .. "self." .. name .. " = " .. name)
    end
  end
  if #lines > 0 then
    table.insert(lines, "\t")
  end
  return lines
end

local function function_snippet(trigger, keyword, description)
  return s(
    { trig = trigger, desc = description },
    fmt(keyword .. " {}({}) -> {}:\n\t{}", {
      i(1, "name"),
      parameters(),
      i(3, "None"),
      i(0, "pass"),
    })
  )
end

return {
  function_snippet("def", "def", "Function (self/cls inside a class)"),
  function_snippet("adef", "async def", "Async function"),

  s(
    { trig = "defd", desc = "Function with a docstring" },
    fmt('def {}({}) -> {}:\n\t"""{}"""\n\t{}', {
      i(1, "name"),
      parameters(),
      i(3, "None"),
      i(4, "Describe what it does."),
      i(0, "pass"),
    })
  ),

  s(
    { trig = "init", desc = "__init__ assigning its parameters" },
    fmt("def __init__(self{}{}) -> None:\n\t{}{}", {
      -- No ", " once the parameters are erased.
      f(function(args)
        return vim.trim(table.concat(args[1], "")) ~= "" and ", " or ""
      end, { 1 }),
      i(1, "value: int"),
      f(assignments, { 1 }),
      i(0),
    })
  ),

  s(
    { trig = "class", desc = "Class (then init for its __init__)" },
    fmt("class {}:\n\t{}", {
      i(1, "Name"),
      i(0, "pass"),
    })
  ),

  s(
    { trig = "prop", desc = "Read-only property" },
    fmt("@property\ndef {}(self) -> {}:\n\treturn self._{}", {
      i(1, "name"),
      i(2, "int"),
      rep(1),
    })
  ),

  s(
    { trig = "main", desc = "main() and its __main__ guard" },
    fmt('def main() -> None:\n\t{}\n\n\nif __name__ == "__main__":\n\tmain()', {
      i(0, "pass"),
    })
  ),

  s(
    { trig = "ifmain", desc = "__main__ guard" },
    fmt('if __name__ == "__main__":\n\t{}', { i(0, "main()") })
  ),

  s(
    { trig = "try", desc = "try / except" },
    fmt("try:\n\t{}\nexcept {} as {}:\n\t{}", {
      i(1, "pass"),
      i(2, "Exception"),
      i(3, "error"),
      i(0, "raise"),
    })
  ),

  s(
    { trig = "with", desc = "Open a file" },
    fmt("with open({}, {}) as {}:\n\t{}", {
      i(1, "path"),
      i(2, '"r"'),
      i(3, "file"),
      i(0, "pass"),
    })
  ),

  s(
    { trig = "test", desc = "pytest test function" },
    fmt("def test_{}() -> None:\n\t{}", {
      i(1, "name"),
      i(0, "assert True"),
    })
  ),

  s({ trig = "doc", desc = "Docstring" }, fmt('"""{}"""', { i(0) })),
}
