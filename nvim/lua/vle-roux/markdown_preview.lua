local M = {}

local state = {
  source_buf = nil,
  preview_buf = nil,
  preview_win = nil,
  temp_file = nil,
}

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_preview_context(bufnr)
  return (valid_buf(state.preview_buf) and bufnr == state.preview_buf)
    or (valid_win(state.preview_win) and vim.api.nvim_get_current_win() == state.preview_win)
end

local function resolve_source_buf(bufnr)
  if is_preview_context(bufnr) and valid_buf(state.source_buf) then
    return state.source_buf
  end
  return bufnr
end

local function cleanup_temp_file()
  if state.temp_file and vim.fn.filereadable(state.temp_file) == 1 then
    vim.fn.delete(state.temp_file)
  end
  state.temp_file = nil
end

local function preview_config()
  local width = math.max(80, math.floor(vim.o.columns * 0.78))
  local height = math.max(20, math.floor((vim.o.lines - vim.o.cmdheight) * 0.88))
  local row = math.max(1, math.floor((vim.o.lines - height) * 0.5) - 1)
  local col = math.max(2, math.floor((vim.o.columns - width) * 0.5))

  return {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Markdown Preview ",
    title_pos = "center",
    zindex = 60,
  }
end

local function reset_state()
  state.source_buf = nil
  state.preview_buf = nil
  state.preview_win = nil
  cleanup_temp_file()
end

local function preview_width()
  if valid_win(state.preview_win) then
    return math.max(60, vim.api.nvim_win_get_width(state.preview_win) - 4)
  end
  return math.max(60, preview_config().width - 4)
end

local function source_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" and vim.bo[bufnr].modified == false then
    cleanup_temp_file()
    return name
  end

  cleanup_temp_file()
  state.temp_file = vim.fn.tempname() .. ".md"
  vim.fn.writefile(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), state.temp_file)
  return state.temp_file
end

local function render_lines(bufnr, width)
  local path = source_path(bufnr)
  local result = vim.system({ "glow", "-s", "auto", "-w", tostring(width), path }, { text = true }):wait()

  if result.code ~= 0 then
    return nil, (result.stderr ~= "" and result.stderr) or "glow failed"
  end

  if result.stdout == "" then
    return { "" }, nil
  end

  return vim.split(result.stdout, "\n", { plain = true, trimempty = false }), nil
end

local function configure_preview_buffer(bufnr)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "markdown"

  vim.keymap.set("n", "q", function()
    require("vle-roux.markdown_preview").close()
  end, { buffer = bufnr, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    require("vle-roux.markdown_preview").close()
  end, { buffer = bufnr, silent = true })
end

local function configure_preview_window(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].list = false
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].colorcolumn = ""
  vim.wo[win].winfixbuf = true
end

local function ensure_markdown_buffer(bufnr)
  if vim.bo[bufnr].filetype ~= "markdown" then
    vim.notify("Markdown preview is only available for markdown buffers", vim.log.levels.WARN)
    return false
  end
  return true
end

local function source_cursor_line(bufnr)
  local source_win = vim.fn.bufwinid(bufnr)
  if source_win ~= -1 then
    return vim.api.nvim_win_get_cursor(source_win)[1]
  end

  local cursor = vim.api.nvim_buf_get_mark(bufnr, '"')
  return math.max(cursor[1], 1)
end

local function sync_view(bufnr)
  bufnr = resolve_source_buf(bufnr)
  if not valid_buf(bufnr) or not valid_buf(state.preview_buf) or not valid_win(state.preview_win) then
    return
  end

  local source_count = vim.api.nvim_buf_line_count(bufnr)
  local preview_count = vim.api.nvim_buf_line_count(state.preview_buf)
  local source_line = math.min(source_cursor_line(bufnr), source_count)

  local target_line = 1
  if source_count > 1 and preview_count > 1 then
    local ratio = (source_line - 1) / (source_count - 1)
    target_line = math.floor(ratio * (preview_count - 1)) + 1
  end

  target_line = math.max(1, math.min(target_line, preview_count))
  vim.api.nvim_win_set_cursor(state.preview_win, { target_line, 0 })
  vim.api.nvim_win_call(state.preview_win, function()
    vim.cmd("normal! zz")
  end)
end

function M.close()
  if valid_win(state.preview_win) then
    vim.api.nvim_win_close(state.preview_win, true)
  elseif valid_buf(state.preview_buf) then
    pcall(vim.api.nvim_buf_delete, state.preview_buf, { force = true })
  end
  reset_state()
end

function M.refresh(bufnr)
  bufnr = bufnr or state.source_buf or vim.api.nvim_get_current_buf()
  bufnr = resolve_source_buf(bufnr)
  if not valid_buf(bufnr) or not ensure_markdown_buffer(bufnr) then
    return
  end

  if not valid_buf(state.preview_buf) or not valid_win(state.preview_win) then
    M.open(bufnr)
    return
  end

  vim.api.nvim_win_set_config(state.preview_win, preview_config())

  local lines, err = render_lines(bufnr, preview_width())
  if not lines then
    vim.notify("Markdown preview failed: " .. err, vim.log.levels.ERROR)
    return
  end

  state.source_buf = bufnr

  vim.bo[state.preview_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, lines)
  vim.bo[state.preview_buf].modifiable = false
  vim.api.nvim_buf_set_name(state.preview_buf, "Markdown Preview")
  vim.api.nvim_win_set_buf(state.preview_win, state.preview_buf)
  configure_preview_window(state.preview_win)
  sync_view(bufnr)
end

function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  bufnr = resolve_source_buf(bufnr)
  if not valid_buf(bufnr) or not ensure_markdown_buffer(bufnr) then
    return
  end

  if valid_win(state.preview_win) and state.source_buf == bufnr then
    M.refresh(bufnr)
    return
  end

  M.close()
  state.preview_buf = vim.api.nvim_create_buf(false, true)
  configure_preview_buffer(state.preview_buf)
  state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, preview_config())
  state.source_buf = bufnr
  vim.api.nvim_set_option_value("winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder", { win = state.preview_win })
  vim.api.nvim_set_option_value("wrap", true, { win = state.preview_win })
  M.refresh(bufnr)
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if valid_win(state.preview_win) and (state.source_buf == bufnr or is_preview_context(bufnr)) then
    M.close()
    return
  end
  M.open(bufnr)
end

function M.refresh_if_visible(bufnr)
  if valid_win(state.preview_win) and state.source_buf == bufnr then
    M.refresh(bufnr)
  end
end

function M.refresh_visible()
  if valid_win(state.preview_win) and valid_buf(state.source_buf) then
    M.refresh(state.source_buf)
  end
end

function M.sync_if_visible(bufnr)
  if valid_win(state.preview_win) and state.source_buf == bufnr then
    sync_view(bufnr)
  end
end

return M
